#ifndef DISPLAY_UTILS_H
#define DISPLAY_UTILS_H

#include <TFT_eSPI.h>
#include <stdint.h>
#include <stddef.h>

extern TFT_eSPI tft;

void tft_drawString(const char* str, int x, int y);
void print_hex_tft(const char *label, const uint8_t *data, size_t len, int x, int y);
void print_chain_id_tft(const char *label, const uint8_t *data, size_t len, int x, int y);
void print_hex_tft_trim_leading_zeros(const char *label, const uint8_t *data, size_t len, int x, int y);
void drawSignConfirmationUI();

#endif // DISPLAY_UTILS_H