#include "display_utils.h"
#include <cstdio>
#include <cstring>

void tft_drawString(const char* str, int x, int y) {
    // For demo, just print with coordinates
    printf("TFT @(%d,%d): %s\n", x, y, str);
}

// Utility: Format hex string with label
static int format_hex_string(char *buf, size_t buf_size,
    const char *label,
    const uint8_t *data, size_t len,
    bool trim_leading_zeros
) {
    int written = snprintf(buf, buf_size, "%s: 0x", label);
    if (written < 0 || (size_t)written >= buf_size) return written;

    size_t start = 0;
    if (trim_leading_zeros) {
        while (start < len && data[start] == 0) {
            start++;
        }
    }

    if (start == len) {
        // All zeros
        written += snprintf(buf + written, buf_size - written, "0");
        return written;
    }

    for (size_t i = start; i < len && (size_t)written < buf_size - 3; i++) {
        written += snprintf(buf + written, buf_size - written, "%02x", data[i]);
    }

    return written;
}

void print_hex_tft(const char *label, const uint8_t *data, size_t len, int x, int y) {
    char buf[256];
    format_hex_string(buf, sizeof(buf), label, data, len, false);
    tft.drawString(buf, x, y);
}

void print_chain_id_tft(const char *label, const uint8_t *data, size_t len, int x, int y) {
    char buf[256];
    int written = format_hex_string(buf, sizeof(buf), label, data, len, false);

    if (len >= 2 && memcmp(data, "\x42\x68", 2) == 0) {
        snprintf(buf + written, sizeof(buf) - written, " (Holesky)");
    }

    tft.drawString(buf, x, y);
}

void print_hex_tft_trim_leading_zeros(const char *label, const uint8_t *data, size_t len, int x, int y) {
    char buf[256];
    format_hex_string(buf, sizeof(buf), label, data, len, true);
    tft.drawString(buf, x, y);
}

void drawSignConfirmationUI() {
    // display: 320, 170
    // draw approve icon
    tft.fillRect(290, 10, 20, 20, TFT_GREEN);
    tft.drawWideLine(298, 26, 306, 14, 3, TFT_BLACK);
    tft.drawWideLine(298, 26, 294, 18, 3, TFT_BLACK);
    // draw reject icon
    tft.fillRect(290, 140, 20, 20, TFT_RED);
    tft.drawWideLine(294, 144, 306, 156, 3, TFT_BLACK);
    tft.drawWideLine(294, 156, 306, 144, 3, TFT_BLACK);
}