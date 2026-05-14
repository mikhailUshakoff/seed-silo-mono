#ifndef RLP_PARSER_H
#define RLP_PARSER_H

#include <stdint.h>
#include <stddef.h>

int rlp_read_length(const uint8_t *data, size_t data_len, size_t *out_len, size_t *out_offset);
const uint8_t* rlp_read_item(const uint8_t *data, size_t data_len, size_t *item_len, size_t *consumed);

#endif // RLP_PARSER_H