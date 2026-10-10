# Security Hardening Notes

Notes on how the seed encryption key is derived today, what is weak about it, and a step-by-step plan to harden it.

## Current flow

**Provisioning** (`utils/key-encryption/src/main.rs`):

```
password (ENCRYPTION_KEY) → keccak256 → 32-byte AES key → AES-256-GCM encrypt seed → input.h → flashed to device
```

**Usage** (`seed_silo/lib/services/transaction_service.dart`):

```
app:    password → keccak256 → 32 bytes ──USB──▶
device: use 32 bytes directly as AES key → AES-GCM decrypt seed → sign
```

## Weaknesses

1. **Fast hash.** Keccak runs at billions of hashes per second on a GPU. Anyone who dumps the device flash (IV + ciphertext + tag) can brute-force the password offline. The GCM tag confirms every correct guess.
2. **No salt.** Every Seed Silo device uses the same password-to-key mapping, so precomputed tables work against all devices.
3. **The flash is readable.** Without flash encryption, the encrypted blob can be dumped with standard tools.
4. **The value sent over USB is the AES key.** Malware on the host can capture it and decrypt the seed. No KDF fixes this.
5. **The key isn't bound to the chip.** A flash dump alone is enough to attack the seed anywhere, for example on a GPU farm.

## Building blocks

### Argon2id (password KDF)

A slow, memory-hard password hash. Each guess costs, for example, 64–256 MiB of RAM and about 0.5–1 s, which makes GPU/ASIC brute force roughly 10⁶× more expensive than Keccak.

- Run it **on the host** (Rust provisioning tool + Dart app), not on the device. The ESP32 doesn't have enough RAM. The device still receives 32 bytes, so the firmware protocol doesn't change.
- It **does not** add entropy. A weak password (for example a 6-digit PIN) is still crackable. Use a strong passphrase.
- It **does not** protect against a compromised host (keylogger, or capturing the hash on USB).

### Salt

A random 16–32 bytes, unique per device. It isn't secret. Store it on the device and expose it with an unauthenticated command (for example `CMD_GET_SALT`), so the device is self-contained and the app keeps no state.

### HMAC peripheral with an eFuse key ("HMAC_efuse")

ESP32-S3 and ESP32-C3 (both boards in this repo) have a hardware HMAC-SHA256 unit that uses a secret key burned into eFuse. The original ESP32 does **not** have it.

- **eFuse** is one-time-programmable memory on the chip. There are 6 key slots (`BLOCK_KEY0..5`) of 256 bits each. Bits can only go from 0 to 1, never back.
- **Read-protected** key slots can't be read by any software, including your own firmware. Only the hardware HMAC unit can use the key.
- API:
  ```c
  #include "esp_hmac.h"
  uint8_t out[32];
  esp_hmac_calculate(HMAC_KEY0, msg, msg_len, out);
  ```
- Burn command (**irreversible**; `HMAC_UP` read-protects the key by default):
  ```bash
  espefuse.py burn_key BLOCK_KEY0 hmac_key.bin HMAC_UP
  ```

Target flow:

```
app:    password → Argon2id(password, salt) → h ──USB──▶
device: aes_key = HMAC_efuse(h) → AES-GCM decrypt seed
```

A flash dump alone is now useless because the AES key depends on a secret that exists only inside that physical chip.

### Secure Boot v2

Secure boot makes the chip run only firmware signed with **your** private key.

- When you enable it, a digest of your public signing key is burned into eFuse.
- On every boot, the ROM bootloader checks the signature of the second-stage bootloader, and the bootloader checks the app. If a signature is invalid, the chip refuses to boot.
- It stops an attacker flashing their own firmware, for example a firmware that uses the eFuse HMAC as an oracle, skips the wrong-password limit, or dumps memory.
- It **does not** encrypt anything and **does not** stop anyone reading flash or eFuse. That's the job of flash encryption and eFuse read-protection.
- The signing key lives on your PC. **Back it up offline. If you lose it, the device can never be updated again.** If it leaks, an attacker can sign malicious firmware.

### Flash encryption

Flash encryption encrypts flash contents with AES-XTS, using a key in a read-protected eFuse.

- By default the key is generated on the chip and never leaves it, so every device has its own key.
- Decryption happens transparently, only while code is running on that same chip. `esptool.py read_flash` and a desoldered flash chip both give only ciphertext.
- What it protects: the encrypted seed blob from `input.h`, which is compiled into the firmware. The firmware itself is open source, so it isn't the secret. Without the blob, an attacker can't even start an offline brute force.
- Conditions:
  1. **Use release mode.** Development mode still allows reflashing over UART. The attacker flashes a dumper app that reads flash through the chip, decrypted.
  2. **Disable JTAG.** Otherwise the attacker can halt the CPU and read decrypted memory.
  3. **Use it together with Secure Boot v2.**
  4. **Not every partition is encrypted.** Only the app, bootloader, partition table and partitions flagged `encrypted` are covered. **NVS needs separate NVS encryption**, which matters if the salt or the wrong-password counter is stored there.
- Limits: fault injection extracted the flash encryption key from ESP32 V1 (LimitedResults, 2019). S3 and C3 are harder targets but not proven safe.
- Arduino + PlatformIO: the Arduino framework ships a precompiled bootloader. Enabling flash encryption and secure boot needs a bootloader built with those options, which probably means switching to `framework = arduino, espidf`. Check this before Step 3.

### Key size: a 64-byte key is useless, the password is the weak point

- AES supports only 16, 24 or 32-byte keys. Seed Silo already uses the maximum (AES-256, 32 bytes).
- A 64-byte key isn't possible with AES-GCM. AES-XTS (flash encryption) takes 64 bytes, but that's two 32-byte keys with different jobs, still 256-bit security.
- A 32-byte key written in hex is 64 characters. That's the same key, not a bigger one.
- 2²⁵⁶ keys is far beyond brute force for any computer that will ever exist. Quantum computers (Grover's algorithm) reduce it to about 2¹²⁸, which is still out of reach.

**The real weak point is the password.** The chain is:

```
password → KDF → 32-byte key
```

The key is only as strong as the password it's derived from. An 8-character password gives roughly 2⁴⁰–2⁵⁰ possibilities, so an attacker guesses passwords and never touches the 2²⁵⁶ keyspace. A bigger key changes nothing.

What actually raises security:
1. **A strong passphrase**: 6+ random diceware words is about 77+ bits.
2. **Argon2id**: makes each guess expensive.
3. **eFuse HMAC + secure boot + flash encryption**: the attacker can't take the blob offline at all.

**Provisioning problem:** the encryption tool needs `aes_key`. There are two options:
1. Generate `hmac_key` on the host, burn it, compute the HMAC on the host, encrypt, then securely delete `hmac_key.bin`. This is simple, but the key existed on the host for a while.
2. Generate the key on the device and have the device encrypt the seed. The key never leaves the chip, which is stronger, but it needs a new provisioning command.

### What each protection stops

| Threat | What stops it |
|---|---|
| Software reads the eFuse key (`espefuse.py`, attacker firmware, your firmware) | eFuse read-protection (`RD_DIS`). Hardware enforces it no matter what code runs. |
| Attacker runs their own firmware and uses the HMAC unit as an oracle (never reads the key, just uses it) | Secure Boot v2: only firmware signed with your key boots. |
| Flash dump of firmware or the encrypted seed | Flash encryption |
| JTAG or UART download mode used to run code or poke memory | Disable JTAG (`DIS_PAD_JTAG`, `DIS_USB_JTAG`) plus secure download mode (`ENABLE_SECURITY_DOWNLOAD`) |
| Online brute force through your own firmware | Firmware rate-limits or wipes after N wrong passwords |
| Voltage or clock glitching, chip decapping | Nothing in software. ESP32 is not a secure element. |

**Secure boot does not protect the eFuse key from being read**; read-protection does that. Secure boot stops other code from *using* the key. You need both:
- Read-protection without secure boot leaves the oracle attack open: the attacker never learns the key but still brute-forces on the chip with their own firmware.
- Secure boot without read-protection is pointless, because the key can be read directly.

## Improvement steps

In order of value per effort.

### Step 1: Argon2id + per-device salt (host side only, no eFuse risk)

1. Choose fixed parameters: Argon2id, `m` = 64–256 MiB, `t` = 3, `p` = 1–4, output 32 bytes. Pick them for the slowest target device that runs the app (mobile).
2. Add a version byte for the KDF parameters, so they can be changed later.
3. `utils/key-encryption`: replace Keccak with the `argon2` crate. Generate a random salt and output it in `input.h`.
4. Firmware: store the salt and add `CMD_GET_SALT` (no password needed). Update `constants.h`.
5. App: add `getSalt()` in `hardware_wallet_service.dart` and replace `keccak256(password)` in `transaction_service.dart` with Argon2id. Pure-Dart Argon2 (`cryptography` package) may be slow, so consider FFI to the native library.
6. Zero the password, the Argon2 output and intermediate buffers (`nullify.dart` / `secure_memzero`).
7. Re-provision every device: decrypt with the old key, re-encrypt with the new key and a **fresh IV**. Never reuse a GCM nonce with the same key.
8. Use a strong passphrase. The KDF only multiplies attack cost.

### Step 2: Bind the key to the chip with the eFuse HMAC

1. Practice on a **spare board** first. Everything below is irreversible.
2. Generate a 256-bit `hmac_key` and burn it to a key slot with purpose `HMAC_UP`. Verify the slot is read-protected (`espefuse.py summary`).
3. Firmware: `aes_key = esp_hmac_calculate(HMAC_KEYn, h)`, decrypt, then zero `aes_key` and `h`.
4. Provisioning: compute the same HMAC on the host (option 1 above), encrypt, and securely delete `hmac_key.bin`. Or implement on-device encryption (option 2).
5. Keep an **offline mnemonic backup**. If the chip dies, the encrypted blob can't be decrypted.

### Step 3: Secure Boot v2 + flash encryption + lock-down

1. Generate the secure boot signing key and back it up offline. **If you lose it, the device can never be updated again.**
2. Enable Secure Boot v2 (release mode).
3. Enable flash encryption (release mode).
4. Confirm these eFuses are burned: `DIS_PAD_JTAG`, `DIS_USB_JTAG`, `ENABLE_SECURITY_DOWNLOAD` (or download mode fully disabled).
5. Check the final state with `espefuse.py summary`.

### Step 4: Rate-limit wrong passwords in firmware

1. Detect a wrong password (GCM tag check fails) and keep a failure counter in flash (encrypted by step 3).
2. Add an increasing delay after each failure. After N failures, wipe the encrypted seed.
3. This only works once step 3 is done. Otherwise an attacker just flashes firmware without the limit.

#### Problem: the seed can't be wiped today

The seed blob is compiled into the firmware: `input.h` turns into constants inside the app partition, and the running app can't safely erase its own code. Move the blob to its own flash partition.

#### 1. Partition table

Add a small data partition to `partitions.csv`. With the `encrypted` flag, flash encryption covers it.

```
# Name,  Type, SubType, Offset, Size,   Flags
seed,    data, 0x40,    ,       0x2000, encrypted
```

- Sector 0 (`0x0000`) holds the IV, ciphertext and tag.
- Sector 1 (`0x1000`) holds the wrong-password counter.

#### 2. Read the blob from the partition instead of the `#define`s

```c
#include "esp_partition.h"

const esp_partition_t* p = esp_partition_find_first(
    ESP_PARTITION_TYPE_DATA, (esp_partition_subtype_t)0x40, "seed");
esp_partition_read(p, 0, blob, sizeof(blob));
```

#### 3. Wipe

```c
esp_partition_erase_range(p, 0, p->size);   // whole partition → 0xFF
```

- NOR flash erase physically resets the sector, and a raw partition has no wear-leveling copies left behind.
- **Don't store the seed in NVS.** NVS keeps old copies of entries until garbage collection, so an "erase" there may leave data behind.
- Also run `secure_memzero` on the RAM buffers (blob, `h`, `aes_key`) before erasing.
- The eFuse key can't be wiped (bits only go 0→1, and the key slot is write-protected). That's fine: erasing the blob alone makes the seed unrecoverable.

#### 4. Provisioning

The blob is ciphertext, so it's safe to send over USB. Add a provisioning command where the firmware receives the blob and writes it to the partition. That works even after flash encryption release mode, where `esptool` can no longer write plaintext.

#### 5. Counter order: save first, then decrypt

An attacker can cut power right after a wrong guess, before the counter is saved, and get unlimited tries. So **increment and save first, then try to decrypt**:

Saving the counter before decryption prevents power-cut bypasses, but the flash-backed counter remains rollbackable. AES-XTS flash encryption provides confidentiality rather than freshness or integrity, so an attacker with the physical flash access assumed by this document can restore an earlier ciphertext snapshot at the same sector and bypass both MAX and the wipe. This design needs non-rollbackable state (for example, a monotonic secure-element/eFuse mechanism), or the stated protection must be limited to attackers who cannot restore flash.

```
1. counter += 1, write to flash (commit)
2. if counter > MAX → erase partition, respond error
3. try AES-GCM decrypt
4. tag OK   → counter = 0, write to flash, continue
   tag fail → zero buffers, respond error
```

#### Notes

- **Flash wear:** about 100k erase cycles per sector is plenty for a counter. To reduce wear further, store the counter as an append-only bit pattern inside one sector (clear one bit per attempt) and erase only on reset.
- **Pick MAX with care**, for example 10. Too low and a typo-prone user wipes their own device.
- **Recovery** after a wipe means the mnemonic backup plus re-provisioning. Make sure the backup exists before you enable the wipe.

### Step 5: Device review on every board

The `super_mini_esp32c3` board signs without showing or confirming the transaction. A compromised host can make it sign anything. For real funds, prefer `lilygo_tdisplay_s3`, which shows the transaction and needs a button press.

### Step 6 (optional, long-term): add an external secure element

See [Secure elements](#secure-elements) below. This replaces the eFuse HMAC with a separate hardened chip, so the secret survives glitching attacks on the ESP32.

## Secure elements

### Ledger

Ledger uses **STMicroelectronics ST33 secure elements**, alongside a normal STM32 microcontroller:

| Device | Secure element | MCU (USB, BLE, screen) |
|---|---|---|
| Nano S (old) | ST31H320 | STM32F042 |
| Nano X | ST33J2M0 | STM32WB55 (BLE) |
| Nano S Plus, Stax, Flex | ST33K1M5 | STM32 |

- The chips are certified CC EAL5+ / EAL6+, with hardware protection against glitching, side channels, probing and decapping.
- Ledger's OS (BOLOS) runs **inside** the secure element. Keys never leave it, and signing happens there too.
- The MCU is an untrusted relay for USB and BLE.
- The downside: the ST33 needs an NDA and its firmware is closed, so it isn't usable for DIY projects.

### Trezor Safe 3/5

Trezor uses an **Infineon OPTIGA Trust M** (EAL6+).

- The seed stays on the MCU, encrypted.
- The secure element holds a secret that is mixed with the PIN, and it rate-limits attempts.
- This is very close to the eFuse HMAC design in this doc, but with a real secure element in place of the ESP32 eFuse, so glitching is much harder.

### Secure elements you can buy for Seed Silo

- **Microchip ATECC608B**: about $1, I2C, no NDA, with Arduino libraries. Coldcard used it. It can store a secret, do HMAC/ECDH, and limit use through monotonic counters.
- **Infineon OPTIGA Trust M**: I2C, with an open host library and breakout boards available. Same chip as Trezor.

Possible design with either chip:

```
app:    password → Argon2id(password, salt) → h ──USB──▶
ESP32:  aes_key = SE_HMAC(h)   (secret + attempt counter live in the secure element)
        → AES-GCM decrypt seed
```

- The secret survives an ESP32 glitch attack because it lives on a separate hardened chip.
- The secure element enforces the rate limit in hardware, so it doesn't depend only on ESP32 secure boot.
- **Protect the I2C link** between the ESP32 and the secure element with an encrypted/authenticated session (both chips support it). Otherwise an attacker can sniff or replay it.
- Keep secure boot and flash encryption on the ESP32 anyway. They still protect the blob and the firmware.

## Limits

- **Host compromise:** a keylogger or USB sniffing gets the password or hash. None of the steps above fix this; only on-device confirmation limits the damage.
- **Physical lab attacks:** voltage glitching and decapping can bypass ESP32 boot checks. S3/C3 are harder targets than ESP32 V1, but they are not hardened like a secure element (Ledger, Trezor Safe).
- **Weak passwords:** no KDF saves a short password.
