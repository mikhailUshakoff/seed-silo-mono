#ifndef RLP_DECODER_H
#define RLP_DECODER_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

typedef enum {
    RLP_OK              =  0,
    RLP_ERR_EMPTY       = -1,  // zero-length input
    RLP_ERR_TRUNCATED   = -2,  // payload extends past buffer
    RLP_ERR_LEN_TOOLONG = -3,  // len_of_len > 4 (won't fit size_t on ESP32)
    RLP_ERR_OVERFLOW    = -4,  // length arithmetic wrapped
} rlp_err_t;

typedef enum {
    RLP_BYTE,    // single byte (prefix 0x00–0x7f); data[0] IS the value
    RLP_STRING,  // byte string (prefix 0x80–0xbf)
    RLP_LIST,    // list of RLP items (prefix 0xc0–0xff)
} rlp_type_t;

typedef struct {
    rlp_type_t   type;
    const uint8_t *payload;   // points to decoded payload bytes
    size_t        payload_len;
    size_t        total_len;  // bytes consumed from source buffer (header + payload)
} rlp_item_t;

/* Decode one RLP item from buf[0..buf_len). */
rlp_err_t rlp_decode(const uint8_t *buf, size_t buf_len, rlp_item_t *out);

/* List iterator — use after decoding an RLP_LIST item. */
typedef struct {
    const uint8_t *cursor;
    size_t         remaining;
} rlp_iter_t;

void      rlp_iter_init(rlp_iter_t *it, const rlp_item_t *list);
bool      rlp_iter_next(rlp_iter_t *it, rlp_item_t *out, rlp_err_t *err);
#endif // RLP_DECODER_H