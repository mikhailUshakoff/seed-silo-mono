#ifndef TX_PARSER_H
#define TX_PARSER_H

#include <stdint.h>
#include <stddef.h>

int parse_eip1559_tx(const uint8_t *tx, uint16_t len);

#endif // TX_PARSER_H