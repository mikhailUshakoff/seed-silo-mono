# Seed Silo - ESP32 Hardware Wallet

A secure hardware wallet implementation built on the ESP32 microcontroller platform.

## Overview

Seed Silo is a hardware wallet designed to provide secure storage and management of cryptocurrency private keys using the ESP32 microcontroller. The device offers secure storage and transaction signing capabilities.

## Project Structure

- `firmware/` - ESP32 firmware and hardware schematics
- `seed_silo/` - Desktop and mobile applications
- `utils/` - Development utils

## Security Notice

This is experimental software. Always verify transactions and backup your seed phrase securely. Use at your own risk.

# Note
## AES256-CBC
Avoid reusing the ciphertext or IV. If you ever re-encrypt the same data with the same IV, you leak information about the key. So always generate a new IV when re-encrypting.
