#include "tx_parser.h"
#include "display_utils.h"
#include "rlp_parser.h"
#include <core/constants.h>
#include <cstring>

// Check if transaction is EIP-1559 type-2
static int is_eip1559_tx(const uint8_t *tx, uint16_t len) {
    if (len < 2 || tx[0] != 0x02) {
        tft.drawString("Not a type-2 tx", 10, 15);
        print_hex_tft("tx", tx, len, 10, 30);
        return CORE_ERR_NOT_TYPE2_TX;
    }
    return CORE_SUCCESS;
}

// Parse RLP list header
static int parse_rlp_list_header(const uint8_t *rlp, size_t rlp_len,
                                  size_t *list_len, size_t *list_offset) {
    if (rlp_read_length(rlp, rlp_len, list_len, list_offset) != 0) {
        tft.drawString("RLP list parse fail", 10, 15);
        return CORE_ERR_RLP_LIST_PARSE;
    }

    if (*list_offset + *list_len > rlp_len) {
        tft.drawString("RLP list length invalid", 10, 15);
        return CORE_ERR_RLP_LIST_LENGTH;
    }

    return CORE_SUCCESS;
}

// Parse and display EIP-20 transfer data
static int parse_eip20_transfer(const uint8_t *field, size_t field_len,
                                 int x, int *y, int line_height) {
    if (field_len != 4 + 32 + 32 || memcmp(field, "\xa9\x05\x9c\xbb", 4) != 0) {
        tft.drawString("Not EIP-20 transfer", x, *y);
        return CORE_ERR_NOT_EIP20_TRANSFER;
    }

    const uint8_t *to_address = field + 4 + 12;  // skip function selector + padding
    const uint8_t *amount = field + 4 + 32;

    tft.drawString("EIP-20 transfer (0xa9059cbb)", x, *y);
    *y += line_height;
    print_hex_tft("to", to_address, 20, x + 5, *y);
    *y += line_height;
    print_hex_tft_trim_leading_zeros("amount", amount, 32, x + 5, *y);

    return CORE_SUCCESS;
}

// Display a separator line
static void draw_separator(int x, int y) {
    tft.setTextColor(TFT_SILVER, TFT_BLACK);
    tft.drawString("------------------------------------------------", x - 5, y);
    tft.setTextColor(TFT_WHITE, TFT_BLACK);
}

// Display a single transaction field
static int display_tx_field(int field_index, const char *field_name,
                             const uint8_t *field, size_t field_len,
                             int x, int *y, int line_height) {
    // Chain ID (field 0)
    if (field_index == 0) {
        print_chain_id_tft(field_name, field, field_len, x, *y);
    }
    // Data field (field 7) - check for EIP-20 transfer
    else if (field_index == 7 && field_len > 0) {
        int result = parse_eip20_transfer(field, field_len, x, y, line_height);
        if (result != CORE_SUCCESS) {
            return result;
        }
    }
    // All other fields
    else {
        print_hex_tft(field_name, field, field_len, x, *y);
    }

    *y += line_height;

    // Draw separator after gas_limit (field 4) and data (field 7)
    if (field_index == 4 || field_index == 7) {
        draw_separator(x, *y);
        *y += line_height;
    }

    return CORE_SUCCESS;
}

// Parse and display all transaction fields
static int parse_tx_fields(const uint8_t *p, size_t remaining) {
    const char *fields[] = {
        "chain_id", "nonce", "max_priority_fee_per_gas", "max_fee_per_gas",
        "gas_limit", "to", "value", "data"
    };
    const int num_fields = sizeof(fields) / sizeof(fields[0]);
    const int x = 10;
    int y = 15;
    const int line_height = 10;

    for (int i = 0; i < num_fields && remaining > 0; i++) {
        size_t field_len = 0, consumed = 0;
        const uint8_t *field = rlp_read_item(p, remaining, &field_len, &consumed);
        if (!field) {
            tft.drawString("RLP field parse fail", x, y);
            return CORE_ERR_RLP_FIELD_PARSE;
        }

        int result = display_tx_field(i, fields[i], field, field_len, x, &y, line_height);
        if (result != CORE_SUCCESS) {
            return result;
        }

        p += consumed;
        remaining -= consumed;
    }

    // Display remaining bytes if any
    if (remaining > 0) {
        print_hex_tft("remaining", p, remaining, x, y);
    }

    return CORE_SUCCESS;
}

// Main parser: parse EIP-1559 type-2 tx and display all fields
int parse_eip1559_tx(const uint8_t *tx, uint16_t len) {
    // Validate transaction type
    int result = is_eip1559_tx(tx, len);
    if (result != CORE_SUCCESS) {
        return result;
    }

    // Extract RLP payload
    const uint8_t *rlp = tx + 1;
    size_t rlp_len = len - 1;

    // Parse RLP list header
    size_t list_len = 0, list_offset = 0;
    result = parse_rlp_list_header(rlp, rlp_len, &list_len, &list_offset);
    if (result != CORE_SUCCESS) {
        return result;
    }

    // Parse and display transaction fields
    const uint8_t *p = rlp + list_offset;
    size_t remaining = list_len;
    return parse_tx_fields(p, remaining);
}