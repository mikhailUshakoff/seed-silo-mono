#!/usr/bin/env bash
#
# Provision and flash Seed Silo firmware in one step:
#   1. build utils/key-encryption (no secrets involved yet)
#   2. prompt for PRIVATE_KEYS / ENCRYPTION_KEY (hidden input, never on argv)
#   3. generate firmware/include/core/input.h (mode 0600)
#   4. build + upload firmware with PlatformIO
#   5. always remove input.h and the env's build artifacts, even on error/Ctrl-C
#
# Usage: scripts/flash-firmware.sh [-e <pio_env>] [-p <upload_port>]
#
# PRIVATE_KEYS / ENCRYPTION_KEY may be pre-set in the environment; otherwise
# they are prompted for. Format of PRIVATE_KEYS: "<hex_key>,<pos>;<hex_key>,<pos>"

set -euo pipefail
set +x          # never trace: commands below handle secrets
umask 077       # every file we create is owner-only
ulimit -c 0     # no core dumps containing secrets

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIRMWARE_DIR="$REPO_ROOT/firmware"
KEY_ENC_DIR="$REPO_ROOT/utils/key-encryption"
KEY_ENC_BIN="$KEY_ENC_DIR/target/release/key-encryption"
INPUT_H="$FIRMWARE_DIR/include/core/input.h"

PIO_ENV="lilygo_tdisplay_s3"
UPLOAD_PORT=""

usage() {
    echo "Usage: $0 [-e <pio_env>] [-p <upload_port>]" >&2
    exit 1
}

while getopts ":e:p:h" opt; do
    case "$opt" in
        e) PIO_ENV="$OPTARG" ;;
        p) UPLOAD_PORT="$OPTARG" ;;
        *) usage ;;
    esac
done

die() { echo "error: $*" >&2; exit 1; }

command -v cargo >/dev/null || die "cargo not found"
command -v pio   >/dev/null || die "pio (PlatformIO) not found"

# Refuse to clobber an existing input.h: it may be the only copy of real data.
[[ -e "$INPUT_H" ]] && die "$INPUT_H already exists. Move or delete it first."

# input.h must be git-ignored so it can never be committed by accident.
git -C "$REPO_ROOT" check-ignore -q "$INPUT_H" \
    || die "$INPUT_H is not git-ignored; refusing to continue"

if [[ "$PIO_ENV" == "super_mini_esp32c3" ]]; then
    echo "WARNING: $PIO_ENV has no display and signs transactions WITHOUT on-device confirmation." >&2
fi

TMP_INPUT=""

secure_rm() {
    local f="$1"
    [[ -n "$f" && -e "$f" ]] || return 0
    if command -v shred >/dev/null; then
        shred -u -z "$f" 2>/dev/null || rm -f "$f"
    else
        rm -f "$f"
    fi
}

cleanup() {
    local rc=$?
    trap - EXIT INT TERM
    unset PRIVATE_KEYS ENCRYPTION_KEY ENCRYPTION_KEY_CONFIRM
    secure_rm "$TMP_INPUT"
    secure_rm "$INPUT_H"
    # Compiled objects/firmware.bin embed the encrypted seed; drop them too.
    rm -rf "$FIRMWARE_DIR/.pio/build/$PIO_ENV"
    if [[ -e "$INPUT_H" ]]; then
        echo "error: failed to remove $INPUT_H — delete it manually!" >&2
        rc=1
    else
        echo "Cleaned up input.h and build artifacts for $PIO_ENV."
    fi
    exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# 1. Build the encryption tool before any secret is in memory.
echo "Building key-encryption..."
cargo build --release --quiet --manifest-path "$KEY_ENC_DIR/Cargo.toml"
[[ -x "$KEY_ENC_BIN" ]] || die "key-encryption binary not found at $KEY_ENC_BIN"

# 2. Collect secrets (hidden input, not in shell history or process args).
if [[ -z "${PRIVATE_KEYS:-}" ]]; then
    read -r -s -p "PRIVATE_KEYS (<hex>,<pos>;...): " PRIVATE_KEYS; echo
fi
[[ -n "$PRIVATE_KEYS" ]] || die "PRIVATE_KEYS is empty"

if [[ -z "${ENCRYPTION_KEY:-}" ]]; then
    read -r -s -p "ENCRYPTION_KEY: " ENCRYPTION_KEY; echo
    read -r -s -p "Confirm ENCRYPTION_KEY: " ENCRYPTION_KEY_CONFIRM; echo
    [[ "$ENCRYPTION_KEY" == "$ENCRYPTION_KEY_CONFIRM" ]] || die "ENCRYPTION_KEY mismatch"
    unset ENCRYPTION_KEY_CONFIRM
fi
[[ -n "$ENCRYPTION_KEY" ]] || die "ENCRYPTION_KEY is empty"

# 3. Generate input.h. Write to a temp file in the same dir, then rename, so a
#    partial/failed run never leaves a truncated input.h behind.
TMP_INPUT="$(mktemp "$FIRMWARE_DIR/include/core/.input.h.XXXXXX")"
echo "Encrypting keys..."
# Secrets go only into the child's environment, never onto its argv.
(
    cd "$KEY_ENC_DIR"
    PRIVATE_KEYS="$PRIVATE_KEYS" ENCRYPTION_KEY="$ENCRYPTION_KEY" "$KEY_ENC_BIN"
) > "$TMP_INPUT"
unset PRIVATE_KEYS ENCRYPTION_KEY

grep -q '^#define GCM_TAG_INITIALIZER' "$TMP_INPUT" \
    || die "key-encryption output looks invalid"
mv "$TMP_INPUT" "$INPUT_H"
TMP_INPUT=""

# 4. Build + upload.
cd "$FIRMWARE_DIR"
PIO_ARGS=(run -e "$PIO_ENV" -t upload)
[[ -n "$UPLOAD_PORT" ]] && PIO_ARGS+=(--upload-port "$UPLOAD_PORT")
echo "Building and uploading firmware ($PIO_ENV)..."
pio "${PIO_ARGS[@]}"

echo "Firmware uploaded successfully."
# 5. cleanup() runs on EXIT.
