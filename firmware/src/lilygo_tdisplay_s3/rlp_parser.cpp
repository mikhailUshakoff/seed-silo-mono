#include "rlp_parser.h"

// RLP length decode: handles strings and lists (short and long)
int rlp_read_length(const uint8_t *data, size_t data_len, size_t *out_len, size_t *out_offset) {
    if (data_len == 0) return -1;

    uint8_t prefix = data[0];

    if (prefix <= 0x7f) {
        *out_len = 1;
        *out_offset = 0;
        return 0;
    } else if (prefix <= 0xb7) {
        size_t len = prefix - 0x80;
        if (len > data_len - 1) return -1;
        *out_len = len;
        *out_offset = 1;
        return 0;
    } else if (prefix <= 0xbf) {
        size_t len_of_len = prefix - 0xb7;
        if (len_of_len + 1 > data_len) return -1;
        // RLP limits length prefix to 4 bytes (32 bits) for strings
        if (len_of_len > 4) return -1;
        size_t len = 0;
        for (size_t i = 0; i < len_of_len; i++) {
            len = (len << 8) | data[1 + i];
        }
        if (len_of_len + len > data_len) return -1;
        *out_len = len;
        *out_offset = 1 + len_of_len;
        return 0;
    } else if (prefix <= 0xf7) {
        size_t len = prefix - 0xc0;
        if (len > data_len - 1) return -1;
        *out_len = len;
        *out_offset = 1;
        return 0;
    } else if (prefix <= 0xff) {
        size_t len_of_len = prefix - 0xf7;
        if (len_of_len + 1 > data_len) return -1;
        // RLP limits length prefix to 3 bytes (24 bits) for lists
        if (len_of_len > 3) return -1;
        size_t len = 0;
        for (size_t i = 0; i < len_of_len; i++) {
            len = (len << 8) | data[1 + i];
        }
        if (len_of_len + len > data_len) return -1;
        *out_len = len;
        *out_offset = 1 + len_of_len;
        return 0;
    }

    return -1;
}

// Reads a single RLP item (string or list element) from data buffer
const uint8_t* rlp_read_item(const uint8_t *data, size_t data_len, size_t *item_len, size_t *consumed) {
    size_t len = 0, offset = 0;
    if (rlp_read_length(data, data_len, &len, &offset) != 0) return NULL;
    if (offset + len > data_len) return NULL;
    *item_len = len;
    *consumed = offset + len;
    return data + offset;
}