# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Seed Silo is a hardware crypto wallet built on ESP32. The repo is a monorepo with three independent pieces:

- `firmware/` — ESP32 firmware (C++/Arduino via PlatformIO) that stores the encrypted seed, derives keys, and signs transactions on-device.
- `seed_silo/` — Flutter desktop/mobile app that talks to the device over serial (USB) and is the user-facing wallet UI.
- `utils/` — standalone Rust CLIs used during development/provisioning, not shipped to the device.

Tested networks: Arbitrum, Base, Ethereum, Linea, Optimism, Scroll, Taiko, zkSync (any EVM chain supporting EIP-1559).

## Security notes

- AES-256-GCM is used to encrypt the seed at rest on the device (`firmware/include/core/src/decrypt_private_key.h`). **Never reuse a nonce with the same key** — nonce reuse in GCM completely breaks confidentiality and authentication. Use a fresh random nonce per encryption, or a counter-based scheme for high-volume use.
- `firmware/include/core/input.h` holds the real encrypted seed/IV/tag constants and is git-ignored. `firmware/include/core/input.example.h` is the checked-in template shape — copy it to `input.h` and fill in real values to build firmware for a provisioned device.
- Private keys/passwords are zeroed after use throughout the firmware (`secure_memzero`) and the Flutter app (`nullify.dart`) — preserve this pattern when touching code that handles key material.
- This is experimental hardware-wallet software; treat correctness of signing/tx-parsing code as security-critical.

## Firmware (`firmware/`)

Built with PlatformIO, `framework = arduino`, targeting two boards defined by env in `platformio.ini`:

- `lilygo_tdisplay_s3` (default) — has a TFT display, used for on-device tx review/approve/reject via buttons.
- `super_mini_esp32c3` — no display. **Signs immediately with no on-device tx review/confirmation** (see Architecture below) — it is not a like-for-like drop-in replacement for the display board from a security standpoint.

Common commands (run from `firmware/`):
```bash
pio run                              # build default env (lilygo_tdisplay_s3)
pio run -e super_mini_esp32c3        # build the other board
pio run -t upload                    # build + flash default env
pio device monitor -b 115200         # serial monitor
```
`firmware/test/` is currently an empty PlatformIO stub (no tests defined yet).

### Architecture

- `firmware/include/core/` is the board-agnostic core: command dispatch, crypto, constants. Shared by both board entry points in `firmware/src/<board>/main.cpp`.
- `firmware/include/core/constants.h` defines the serial protocol: command bytes (`CMD_GET_VERSION`, `CMD_GET_PUBKEY`, `CMD_SIGN`) and response/error codes (`CORE_SUCCESS`, `CORE_ERR_*`). This file is the source of truth for the wire protocol and must stay in sync with `seed_silo/lib/services/hardware_wallet_service.dart` on the app side.
- `firmware/include/core/command_handlers.h` implements the three commands by reading fixed-format requests off `Serial` and writing fixed-format responses back. Each handler: decrypts the private key from the encrypted seed blob at a given `pos` (`decrypt_private_key`), does the crypto op, zeroes secrets, responds.
- `firmware/include/core/src/` holds the individual crypto steps (`decrypt_private_key`, `get_public_key`, `sign_message`, `secure_memzero`), built on `lib/secp256k1` and `lib/sha3_keccak`.
- `firmware/lib/rlp_decoder` decodes raw RLP-encoded EIP-1559 transactions so the firmware can render a human-readable summary before asking the user to approve/reject a signature (see `print_eip1559_tx.cpp`, used only in the `lilygo_tdisplay_s3` variant with its TFT screen).
- `main.cpp` per board owns the event loop and diverges meaningfully between boards: `lilygo_tdisplay_s3` reads a command, and for `CMD_SIGN` parses+displays the tx and waits for a physical button press (approve/reject) before calling `sign_cmd_response`. `esp32c3_super_mini` has no display wiring at all — its `CMD_SIGN` path calls `sign_cmd_get_msg_signature` and responds immediately, with no parsing, display, or user confirmation step. Treat this as a deliberate but security-relevant gap, not an oversight, when working on either board's flow.
- `firmware/boards/*.json` are custom PlatformIO board definitions (not upstream), referenced via `boards_dir = ./boards`.

## Flutter app (`seed_silo/`)

Standard Flutter project. Common commands (run from `seed_silo/`):
```bash
flutter pub get
flutter analyze                      # lint (flutter_lints via analysis_options.yaml)
flutter test                         # run all tests
flutter test test/services/network_service_test.dart   # single test file
flutter run                          # run on connected device/desktop
```

### Architecture

- `lib/services/serial_service.dart` — low-level USB serial transport (via `flutter_libserialport`).
- `lib/services/hardware_wallet_service.dart` — implements the device wire protocol on top of `serial_service`: command bytes/response formats here must match `firmware/include/core/constants.h` exactly (command IDs, byte lengths, big-endian length prefixes, success code `0x01`). This is the primary integration point between app and firmware.
- `lib/services/transaction_service.dart`, `network_service.dart`, `token_service.dart` — build/broadcast transactions, manage EVM network configs and token lists (persisted via `shared_preferences`).
- `lib/providers/` — `ChangeNotifier`-based state (Provider package) for networks and tokens, consumed by screens.
- `lib/screens/` — UI flow: preload → main → transfer → transfer confirm, plus network/token management screens.
- `lib/utils/nullify.dart` — helpers to zero out sensitive `Uint8List`/`List<int>` buffers after use (passwords/keys); use when handling secrets in Dart, mirroring `secure_memzero` on the firmware side.

## Rust utils (`utils/`)

Three independent Cargo crates, each built/run separately:

```bash
cd utils/<crate> && cargo build --release && cargo run
```

- `key-generation` — generates a mnemonic/keypair (uses `alloy-signer-local`).
- `key-encryption` — reads one or more `hex_private_key,position` pairs from `PRIVATE_KEYS` plus an `ENCRYPTION_KEY` env var, AES-256-GCM encrypts them into a 256-byte buffer, and prints a ready-to-use `input.h` (IV/ciphertext/tag `#define`s) to stdout — this is how you provision the constants firmware reads via `decrypt_private_key`. Has real unit tests: `cargo test`.
- `sig-compare` — verifies that a signature produced by the device (or a local signer) matches what was broadcast on-chain; fetches transactions via the Etherscan API (`API_KEY`) or explicit `TX_HASHES`, and RPC (`RPC_URL`). See `utils/sig-compare/README.md` for full env var config (`PRIVATE_KEY`, `API_KEY`, `TX_HASHES`, `RPC_URL`, `TX_COUNT`).
