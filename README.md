# Seed Silo - ESP32 Hardware Wallet

A secure hardware wallet implementation built on the ESP32 microcontroller platform.

## Overview

Seed Silo is a hardware wallet designed to provide secure storage and management of cryptocurrency private keys using the ESP32 microcontroller. The device offers secure storage and transaction signing capabilities.

## Tested Networks
- Arbitrum
- Base
- **Ethereum**
- Linea
- Optimism
- Scroll
- Taiko
- zkSync

## Project Structure

- `firmware/` - ESP32 firmware and hardware schematics
- `seed_silo/` - Desktop and mobile applications
- `utils/` - Development utils

## Security Notice

This is experimental software. Always verify transactions and backup your seed phrase securely. Use at your own risk.

# Note
## AES-256-GCM
Never reuse a nonce with the same key. Nonce reuse in GCM completely breaks the security of the encryption and authentication. Always generate a fresh random nonce for each encryption operation, or use a counter-based nonce strategy for high-volume scenarios.
