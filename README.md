# Seed Silo - ESP32 Hardware Wallet

<img src="seed_silo/assets/icon/seed_silo_mark.png" alt="Seed Silo icon" width="120">

Hardware crypto wallet built on ESP32. Stores an encrypted seed, derives keys, and signs transactions on-device; a Flutter app talks to it over USB serial.

## Repo layout

| Path | What |
|---|---|
| [`firmware/`](firmware/) | ESP32 firmware (C++/Arduino, PlatformIO). Encrypts/decrypts the seed, signs transactions. |
| [`seed_silo/`](seed_silo/) | Flutter desktop/mobile app - the user-facing wallet UI, talks to the device over serial. |
| [`utils/`](utils/) | Standalone Rust CLIs for provisioning/dev (key generation, seed encryption, signature verification). Not shipped to the device. |

Tested networks: Arbitrum, Base, Ethereum, Linea, Optimism, Scroll, Taiko, zkSync (any EVM chain supporting EIP-1559).

## Boards

Two firmware targets, defined by env in `firmware/platformio.ini`:

- `lilygo_tdisplay_s3` (default) - has a TFT display; transactions are parsed, shown on-screen, and require a physical button press to approve/reject before signing.
- `super_mini_esp32c3` - no display, **signs immediately with no on-device review or confirmation**. Not a like-for-like drop-in for the display board - treat it as a deliberate, security-relevant tradeoff, not a bug.

## Getting started

### Firmware

```bash
cd firmware
cp include/core/input.example.h include/core/input.h   # fill in real encrypted-seed constants
pio run                              # build default env (lilygo_tdisplay_s3)
pio run -e super_mini_esp32c3        # or the no-display board
pio run -t upload                    # build + flash
pio device monitor -b 115200         # serial monitor
```

`input.h` is git-ignored; generate its values with `utils/key-encryption` (see below).

### App

```bash
cd seed_silo
flutter pub get
flutter run
```

### Provisioning utils

```bash
cd utils/<crate>   # key-generation | key-encryption | sig-compare
cargo build --release && cargo run
```

`key-generation` makes a mnemonic/keypair, `key-encryption` AES-256-GCM encrypts a private key into the `input.h` constants firmware expects, `sig-compare` cross-checks a device-produced signature against what actually got broadcast on-chain. See `utils/sig-compare/README.md` for its env vars.

## Security notes

- This is experimental hardware-wallet software. Always verify transactions on-device (where supported) and back up your seed phrase securely. Use at your own risk.
- AES-256-GCM encrypts the seed at rest (`firmware/include/core/src/decrypt_private_key.h`). **Never reuse a nonce with the same key** - nonce reuse in GCM completely breaks confidentiality and authentication. Use a fresh random nonce per encryption, or a counter-based scheme for high-volume use.
- Private keys/passwords are zeroed after use throughout the firmware (`secure_memzero`) and the Flutter app (`nullify.dart`).
- The `super_mini_esp32c3` board signs without any on-device tx review - see [Boards](#boards).

## License

MIT - see [LICENSE](LICENSE).
