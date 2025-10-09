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
    uint8_t response = CORE_SUCCESS;
    Serial.write(&response, 1);
}

void handle_get_pubkey_cmd() {
    uint8_t key[32];
    if (Serial.readBytes(key, sizeof(key)) != sizeof(key)) {
        error_response(CORE_ERR_WRONG_DATA_FORMAT);
        return;
    }

    byte pos;
    if (Serial.readBytes(&pos, 1) != 1) {
        error_response(CORE_ERR_WRONG_DATA_FORMAT);
        return;
    }

    uint8_t private_key[32];
    uint8_t public_key[65] = {0};

    int decrypt_result = decrypt_private_key(key, pos, private_key);
    secure_memzero(key, sizeof(key));

    if (decrypt_result != CORE_SUCCESS) {
        secure_memzero(private_key, sizeof(private_key));
        error_response(decrypt_result);
        return;
    }

    int public_key_result = get_public_key(private_key, public_key);
    secure_memzero(private_key, sizeof(private_key));

    if (public_key_result != CORE_SUCCESS) {
        error_response(public_key_result);
        return;
    }

    uint8_t response[66];
    response[0] = CORE_SUCCESS;
    memcpy(response + 1, public_key, 65);

    Serial.write(response, sizeof(response));
}

int sign_cmd_get_msg_signature(
    uint8_t* out_signature,
    int* out_rec_id,
    uint8_t* out_message,
    uint16_t* out_message_len
) {
    uint8_t key[32];
    if (Serial.readBytes(key, sizeof(key)) != sizeof(key)) {
        return CORE_ERR_WRONG_DATA_FORMAT;
    }

    byte pos;
    if (Serial.readBytes(&pos, 1) != 1) {
        return CORE_ERR_WRONG_DATA_FORMAT;
    }

    uint8_t private_key[32];
    int decrypt_result = decrypt_private_key(key, pos, private_key);
    secure_memzero(key, sizeof(key));

    if (decrypt_result != CORE_SUCCESS) {
        secure_memzero(private_key, sizeof(private_key));
        return decrypt_result;
    }

    uint8_t len_bytes[2];
    if (Serial.readBytes(len_bytes, 2) != 2) {
        secure_memzero(private_key, sizeof(private_key));
        return CORE_ERR_WRONG_DATA_FORMAT;
    }

    *out_message_len = (len_bytes[0] << 8) | len_bytes[1];
    if (*out_message_len == 0 || *out_message_len > MAX_MSG_LEN) {
        secure_memzero(private_key, sizeof(private_key));
        return CORE_ERR_WRONG_DATA_FORMAT;
    }

    if (Serial.readBytes(out_message, *out_message_len) != *out_message_len) {
        secure_memzero(private_key, sizeof(private_key));
        return CORE_ERR_WRONG_DATA_FORMAT;
    }

    uint8_t hash[32] = {0};
    keccak256(out_message, *out_message_len, hash);

    int sign_result = sign(private_key, hash, out_signature, out_rec_id);
    secure_memzero(private_key, sizeof(private_key));

    if (sign_result != CORE_SUCCESS) {
        return sign_result;
    }

    if (*out_rec_id < 0 || *out_rec_id > 255) {
        return CORE_ERR_WRONG_RECOVERY_ID;
    }

    return CORE_SUCCESS;
}

void sign_cmd_response(
    uint8_t* signature,
    int rec_id
){
    uint8_t response[66];
    response[0] = CORE_SUCCESS;
    memcpy(response + 1, signature, 64);
    response[65] = (uint8_t)rec_id;

    Serial.write(response, sizeof(response));
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

    if (result != CORE_SUCCESS) {
        error_response(result);
        return;
    }

    sign_cmd_response(signature, rec_id);
}


