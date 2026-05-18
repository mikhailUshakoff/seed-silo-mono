#include "print_eip1559_tx.h"
#include <core/constants.h>
#include <rlp_decoder.h>
#include <TFT_eSPI.h>
#include <cstring>
#include <cstdio>

// External TFT instance (defined in main.cpp)
extern TFT_eSPI tft;

// Utility: Print hex to TFT (or console here) with label at (x,y)
static int format_hex_string(char *buf, size_t buf_size,
    const char *label,
    const uint8_t *data, size_t len,
    bool trim_leading_zeros
) {
    int written = snprintf(buf, buf_size, "%s: 0x", label);
    if (written < 0 || (size_t)written >= buf_size) return written;

    size_t start = 0;
    if (trim_leading_zeros) {
        while (start < len && data[start] == 0) start++;
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

inline bool not_eip1559_tx(const uint8_t *tx, uint16_t len) {
    return len < 28 || tx[0] != 0x02;
}

// Main parser: parse EIP-1559 type-2 tx and print all fields
int print_eip1559_tx(const uint8_t *tx, uint16_t len) {
    if (not_eip1559_tx(tx, len)) {
        tft.drawString("Not a type-2 tx", 10, 15);
        print_hex_tft("tx", tx, len, 10, 30);
        return CORE_ERR_NOT_TYPE2_TX;
    }

    // Skip the 0x02 type prefix, decode the outer RLP list
    rlp_item_t outer;
    rlp_err_t err = rlp_decode(tx + 1, len - 1, &outer);
    if (err != RLP_OK) {
        tft.drawString("RLP list parse fail", 10, 15);
        return CORE_ERR_RLP_LIST_PARSE;
    }
    if (outer.type != RLP_LIST) {
        tft.drawString("RLP: expected list", 10, 15);
        return CORE_ERR_RLP_LIST_PARSE;
    }

    const char *fields[] = {
        "chain_id", "nonce", "max_priority_fee_per_gas", "max_fee_per_gas",
        "gas_limit", "to", "value", "data", "access_list"
    };
    const int num_fields = sizeof(fields) / sizeof(fields[0]);

    int x = 10;
    int y = 15;
    const int line_height = 10;

    rlp_iter_t it;
    rlp_iter_init(&it, &outer);

    rlp_item_t field;
    rlp_err_t field_err = RLP_OK;

    for (int i = 0; i < num_fields; i++) {
        if (!rlp_iter_next(&it, &field, &field_err)) {
            // Ran out of fields before expected — only an error if iterator failed
            if (field_err != RLP_OK) {
                tft.drawString("RLP field parse fail", x, y);
                return CORE_ERR_RLP_FIELD_PARSE;
            }
            break;
        }

        const uint8_t *payload = field.payload;
        size_t payload_len     = field.payload_len;

        if (i == 0) {
            // chain_id
            print_chain_id_tft(fields[i], payload, payload_len, x, y);

        } else if (i == 7 && payload_len > 0) {
            // data field: expect EIP-20 transfer calldata
            if (payload_len != 4 + 32 + 32 || memcmp(payload, "\xa9\x05\x9c\xbb", 4) != 0) {
                tft.drawString("Not EIP-20 transfer", x, y);
                return CORE_ERR_NOT_EIP20_TRANSFER;
            }

            const uint8_t *to_address = payload + 4 + 12; // selector (4) + address padding (12)
            const uint8_t *amount     = payload + 4 + 32;

            tft.drawString("EIP-20 transfer (0xa9059cbb)", x, y);
            x += 5;
            y += line_height;
            print_hex_tft("to", to_address, 20, x, y);
            y += line_height;
            print_hex_tft_trim_leading_zeros("amount", amount, 32, x, y);
            x -= 5;
        } else if (i == 8) {
            // access_list is an RLP list — just show its length
            if (field.type == RLP_LIST && field.payload_len == 0) {
                tft.drawString("access_list: []", x, y);
            } else {
                // non-empty access list — show raw bytes
                print_hex_tft("access_list", field.payload, field.payload_len, x, y);
            }
        } else {
            print_hex_tft(fields[i], payload, payload_len, x, y);
        }

        if (i == 4 || i == 7) {
            y += line_height;
            tft.setTextColor(TFT_SILVER, TFT_BLACK);
            tft.drawString("------------------------------------------------", x - 5, y);
            tft.setTextColor(TFT_WHITE, TFT_BLACK);
        }

        y += line_height;
    }

    // Any bytes left in the iterator print as remainder
    print_hex_tft("remaining", it.cursor, it.remaining, x, y);

    return CORE_SUCCESS;
}