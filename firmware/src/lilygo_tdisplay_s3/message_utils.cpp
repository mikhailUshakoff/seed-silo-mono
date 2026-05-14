#include "message_utils.h"
#include <core/src/secure_memzero.h>

uint8_t signature[64] = {0};
int rec_id = 0;
uint8_t message[MAX_MSG_LEN];
uint16_t msg_len = 0;

void clear_message() {
    secure_memzero(message, msg_len);
    msg_len = 0;
}

void clear_signature() {
    secure_memzero(signature, sizeof(signature));
    rec_id = 0;
}