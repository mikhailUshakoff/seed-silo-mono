#ifndef MESSAGE_UTILS_H
#define MESSAGE_UTILS_H

#include <stdint.h>
#include <core/constants.h>

extern uint8_t message[MAX_MSG_LEN];
extern uint16_t msg_len;
extern uint8_t signature[64];
extern int rec_id;

void clear_message();
void clear_signature();

#endif // MESSAGE_UTILS_H