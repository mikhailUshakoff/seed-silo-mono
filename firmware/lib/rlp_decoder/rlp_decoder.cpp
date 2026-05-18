#include "rlp_decoder.h"
#include <string.h>

/* ---------------------------------------------------------------------------
 * Internal: decode a multi-byte big-endian length field.
 * Returns RLP_ERR_OVERFLOW if result would exceed SIZE_MAX.
 * --------------------------------------------------------------------------*/
static rlp_err_t decode_long_len(const uint8_t *src, size_t len_of_len,
                                  size_t *out)
{
    /* len_of_len is already validated <= 4 by caller */
    size_t len = 0;
    for (size_t i = 0; i < len_of_len; i++) {
        /* Guard against shift overflow (size_t is 32-bit on ESP32) */
        if (len > (SIZE_MAX >> 8)) return RLP_ERR_OVERFLOW;
        len = (len << 8) | src[i];
    }
    *out = len;
    return RLP_OK;
}

/* ---------------------------------------------------------------------------
 * rlp_decode — decode one item.
 * --------------------------------------------------------------------------*/
rlp_err_t rlp_decode(const uint8_t *buf, size_t buf_len, rlp_item_t *out)
{
    if (!buf || buf_len == 0) return RLP_ERR_EMPTY;

    uint8_t prefix = buf[0];

    /* --- Single byte (0x00–0x7f) ---------------------------------------- */
    if (prefix <= 0x7f) {
        out->type        = RLP_BYTE;
        out->payload     = buf;          /* the byte itself */
        out->payload_len = 1;
        out->total_len   = 1;
        return RLP_OK;
    }

    /* --- Short string (0x80–0xb7): 0–55 bytes ---------------------------- */
    if (prefix <= 0xb7) {
        size_t len = prefix - 0x80u;
        if (1 + len > buf_len) return RLP_ERR_TRUNCATED;
        out->type        = RLP_STRING;
        out->payload     = buf + 1;
        out->payload_len = len;
        out->total_len   = 1 + len;
        return RLP_OK;
    }

    /* --- Long string (0xb8–0xbf): length in next 1–4 bytes --------------- */
    if (prefix <= 0xbf) {
        size_t len_of_len = prefix - 0xb7u;
        if (len_of_len > 4)              return RLP_ERR_LEN_TOOLONG;
        if (1 + len_of_len > buf_len)    return RLP_ERR_TRUNCATED;

        size_t len;
        rlp_err_t e = decode_long_len(buf + 1, len_of_len, &len);
        if (e != RLP_OK) return e;

        /* Check: header + payload fits */
        size_t header = 1 + len_of_len;
        if (len > buf_len - header)      return RLP_ERR_TRUNCATED;

        out->type        = RLP_STRING;
        out->payload     = buf + header;
        out->payload_len = len;
        out->total_len   = header + len;
        return RLP_OK;
    }

    /* --- Short list (0xc0–0xf7): 0–55 bytes of list payload -------------- */
    if (prefix <= 0xf7) {
        size_t len = prefix - 0xc0u;
        if (1 + len > buf_len) return RLP_ERR_TRUNCATED;
        out->type        = RLP_LIST;
        out->payload     = buf + 1;
        out->payload_len = len;
        out->total_len   = 1 + len;
        return RLP_OK;
    }

    /* --- Long list (0xf8–0xff): length in next 1–4 bytes ---------------- */
    {
        size_t len_of_len = prefix - 0xf7u;
        if (len_of_len > 4)              return RLP_ERR_LEN_TOOLONG;
        if (1 + len_of_len > buf_len)    return RLP_ERR_TRUNCATED;

        size_t len;
        rlp_err_t e = decode_long_len(buf + 1, len_of_len, &len);
        if (e != RLP_OK) return e;

        size_t header = 1 + len_of_len;
        if (len > buf_len - header)      return RLP_ERR_TRUNCATED;

        out->type        = RLP_LIST;
        out->payload     = buf + header;
        out->payload_len = len;
        out->total_len   = header + len;
        return RLP_OK;
    }
}

/* ---------------------------------------------------------------------------
 * List iterator
 * --------------------------------------------------------------------------*/
void rlp_iter_init(rlp_iter_t *it, const rlp_item_t *list)
{
    it->cursor    = list->payload;
    it->remaining = list->payload_len;
}

bool rlp_iter_next(rlp_iter_t *it, rlp_item_t *out, rlp_err_t *err)
{
    if (it->remaining == 0) return false;

    rlp_err_t e = rlp_decode(it->cursor, it->remaining, out);
    if (e != RLP_OK) {
        if (err) *err = e;
        return false;
    }

    it->cursor    += out->total_len;
    it->remaining -= out->total_len;
    return true;
}