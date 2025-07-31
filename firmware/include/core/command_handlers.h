#include <TFT_eSPI.h>
#include <mbedtls/aes.h>
#include <uECC.h>
#include <KeccakCore.h>
#include <input.h>

#include "constants.h"
#include "src/decrypt_private_key.h"
#include "src/get_public_key.h"
#include "src/sign_message.h"

constexpr size_t MAX_MSG_LEN = 1024;

void error_response(uint8_t code) {
    Serial.write(&code, 1);
}

void secure_memzero(volatile void* ptr, size_t len) {
    if (!ptr) return;
    volatile uint8_t* p = (volatile uint8_t*)ptr;
    while (len--) {
        *p++ = 0;
    }
}

void handle_get_version_cmd() {
    uint8_t response = RESPONSE_OK;
    Serial.write(&response, 1);
}

void handle_get_pubkey_cmd() {
    uint8_t key[32];
    if (Serial.readBytes(key, sizeof(key)) != sizeof(key)) {
        error_response(ERROR_WRONG_DATA_FORMAT);
        return;
    }

    uint8_t private_key[32];
    uint8_t public_key[65] = {0};
    decrypt_private_key(key, private_key);
    secure_memzero(key, sizeof(key));

    int success = get_public_key(private_key, public_key);
    secure_memzero(private_key, sizeof(private_key));

    if (!success) {
        error_response(RESPONSE_FAIL);
        return;
    }

    uint8_t response[66];
    response[0] =RESPONSE_OK;
    memcpy(response + 1, public_key, 65);

    Serial.write(response, sizeof(response));
}

#define STATUS_OK 0
#define STATUS_ERR 1

int decode_sign_data(uint8_t *out_private_key, uint8_t *out_message, uint16_t *out_msg_len) {
    uint8_t key[32];
    if (Serial.readBytes(key, 32) != 32) {
        error_response(ERROR_WRONG_DATA_FORMAT);
        return STATUS_ERR;
    }

    decrypt_private_key(key, out_private_key);
    secure_memzero(key, sizeof(key));

    uint8_t len_bytes[2];
    if (Serial.readBytes(len_bytes, 2) != 2) {
        secure_memzero(out_private_key, 32);
        error_response(ERROR_WRONG_DATA_FORMAT);
        return STATUS_ERR;
    }

    uint16_t msg_len = (len_bytes[0] << 8) | len_bytes[1];
    if (msg_len == 0 || msg_len > MAX_MSG_LEN) {
        secure_memzero(out_private_key, 32);
        error_response(ERROR_WRONG_DATA_FORMAT);
        return STATUS_ERR;
    }

    if (Serial.readBytes(out_message, msg_len) != msg_len) {
        secure_memzero(out_private_key, 32);
        error_response(ERROR_WRONG_DATA_FORMAT);
        return STATUS_ERR;
    }

    *out_msg_len = msg_len;
    return STATUS_OK;
}

int sign_cmd_get_msg_signature(
    uint8_t* out_signature,
    int* out_rec_id,
    uint8_t* out_message,
    uint16_t* out_message_len
) {
    uint8_t key[32];
    if (Serial.readBytes(key, sizeof(key)) != sizeof(key)) {
        error_response(ERROR_WRONG_DATA_FORMAT);
        return STATUS_ERR;
    }

    uint8_t private_key[32];
    decrypt_private_key(key, private_key);
    secure_memzero(key, sizeof(key));

    uint8_t len_bytes[2];
    if (Serial.readBytes(len_bytes, 2) != 2) {
        secure_memzero(private_key, sizeof(private_key));
        error_response(ERROR_WRONG_DATA_FORMAT);
        return STATUS_ERR;
    }

    *out_message_len = (len_bytes[0] << 8) | len_bytes[1];
    if (*out_message_len == 0 || *out_message_len > MAX_MSG_LEN) {
        error_response(ERROR_WRONG_DATA_FORMAT);
        secure_memzero(private_key, sizeof(private_key));
        return STATUS_ERR;
    }

    if (Serial.readBytes(out_message, *out_message_len) != *out_message_len) {
        error_response(ERROR_WRONG_DATA_FORMAT);
        secure_memzero(private_key, sizeof(private_key));
        return STATUS_ERR;
    }

    uint8_t hash[32] = {0};
    keccak256(out_message, *out_message_len, hash);

    int success = sign(private_key, hash, out_signature, out_rec_id);
    secure_memzero(private_key, sizeof(private_key));

    if (!success) {
        error_response(RESPONSE_FAIL);
        return STATUS_ERR;
    }

    return STATUS_OK;
}

int sign_cmd_response(
    uint8_t* signature,
    int rec_id
){
    if (rec_id < 0 || rec_id > 255) {
        error_response(ERROR_WRONG_RECOVERY_ID);
        return STATUS_ERR;
    }
    uint8_t response[66];
    response[0] = RESPONSE_OK;
    memcpy(response + 1, signature, 64);
    response[65] = (uint8_t)rec_id;

    Serial.write(response, sizeof(response));

    return STATUS_OK;
}

void handle_sign_cmd() {
    uint8_t message[MAX_MSG_LEN];
    uint16_t message_len;
    uint8_t signature[64] = {0};
    int rec_id = 0;

    int result = sign_cmd_get_msg_signature(
        signature,
        &rec_id,
        message,
        &message_len
    );

    if (result != STATUS_OK) return;

    sign_cmd_response(signature, rec_id);
}
/*
    uint8_t key[32];
    if (Serial.readBytes(key, sizeof(key)) != sizeof(key)) {
        error_response(ERROR_WRONG_DATA_FORMAT);
        return;
    }

    uint8_t private_key[32];
    decrypt_private_key(key, private_key);
    secure_memzero(key, sizeof(key));

    uint8_t len_bytes[2];
    if (Serial.readBytes(len_bytes, 2) != 2) {
        secure_memzero(private_key, sizeof(private_key));
        error_response(ERROR_WRONG_DATA_FORMAT);
        return;
    }

    uint16_t msg_len = (len_bytes[0] << 8) | len_bytes[1];
    if (msg_len == 0 || msg_len > MAX_MSG_LEN) {
        error_response(ERROR_WRONG_DATA_FORMAT);
        secure_memzero(private_key, sizeof(private_key));
        return;
    }

    static uint8_t message[MAX_MSG_LEN];
    if (Serial.readBytes(message, msg_len) != msg_len) {
        error_response(ERROR_WRONG_DATA_FORMAT);
        secure_memzero(private_key, sizeof(private_key));
        return;
    }

    uint8_t hash[32] = {0};
    keccak256(message, msg_len, hash);

    uint8_t signature[64] = {0};
    uint8_t rec_id = 0;
    int success = sign(private_key, hash, signature, &rec_id);
    secure_memzero(private_key, sizeof(private_key));

    if (!success) {
        error_response(RESPONSE_FAIL);
        return;
    }

    uint8_t response[66];
    response[0] = RESPONSE_OK;
    memcpy(response + 1, signature, 64);
    response[65] = rec_id;

    Serial.write(response, sizeof(response));
}*/


