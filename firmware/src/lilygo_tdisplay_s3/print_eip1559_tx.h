#ifndef PRINT_TX_H
#define PRINT_TX_H

#include <cstdint>
#include <cstdbool>
#include <cstddef>

// TFT display functions (require external tft object)
void print_hex_tft(const char *label, const uint8_t *data, size_t len, int x, int y);
void print_chain_id_tft(const char *label, const uint8_t *data, size_t len, int x, int y);
void print_hex_tft_trim_leading_zeros(const char *label, const uint8_t *data, size_t len, int x, int y);

// Transaction type checking
bool is_eip1559_tx(const uint8_t *tx, uint16_t len);

// Main parser: parse EIP-1559 type-2 tx and print all fields
// Returns CORE_SUCCESS on success, or error code on failure
int print_eip1559_tx(const uint8_t *tx, uint16_t len);

#endif // PRINT_TX_H