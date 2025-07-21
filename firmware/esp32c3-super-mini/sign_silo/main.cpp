#include <Arduino.h>
#include <mbedtls/aes.h>

extern "C" {
    #include "sha3_keccak/sha3.h"
  }

#include "secp256k1/include/secp256k1_recovery.h"
#include "secp256k1/src/secp256k1_c.h"
#include "secp256k1/src/module/recovery/main_impl.h"
#include "input.h"

#define CMD_CHECK_STATUS 0x01
#define CMD_GET_PUBKEY 0x02
#define CMD_SIGN 0x03

#define RESPONSE_OK 0xF0
#define RESPONSE_FAIL 0xF1
#define ERROR_WRONG_CMD 0x01
#define ERROR_WRONG_DATA_FORMAT 0x02

uint8_t ZEROS[32] = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

void setup() {  //.......................setup
    Serial.begin(115200);
}

void keccak256(uint8_t* input, size_t input_len, uint8_t* output) {
    sha3_keccak(input, input_len, output, 32);
}

void decrypt_private_key(uint8_t *key, uint8_t *output) {
    mbedtls_aes_context aes;
    mbedtls_aes_init(&aes);

    // Set AES key (256-bit)
    mbedtls_aes_setkey_enc(&aes, key, 256);

    // Set AES IV
    unsigned char iv[16] = AES_IV_INITIALIZER;

    // Set encrypted data
    unsigned char encrypted_data[48] = ENCRYPTED_DATA_INITIALIZER;

    // Print decrypted data
    mbedtls_aes_crypt_cbc(&aes, MBEDTLS_AES_DECRYPT, 48, iv, encrypted_data, output);

    // Clean up
    mbedtls_aes_free(&aes);
}

// get public key
// 1 - success
// 0 - fail
int get_public_key(uint8_t *private_key, uint8_t *output) {
    secp256k1_context *ctx;
    ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);

    secp256k1_pubkey pubkey;
    if (!secp256k1_ec_pubkey_create(ctx, &pubkey, private_key)) {
        secp256k1_context_destroy(ctx);
        return 0;
    }

    size_t len = 65;
    if (!secp256k1_ec_pubkey_serialize(ctx, output, &len, &pubkey, SECP256K1_EC_UNCOMPRESSED)) {
        secp256k1_context_destroy(ctx);
        return 0;
    }

    secp256k1_context_destroy(ctx);
    return 1;
}

// sign
// 1 - success
// 0 - fail
int sign(uint8_t* private_key, uint8_t* message_hash, uint8_t* output, uint8_t* rec_id) {
    secp256k1_context *ctx;
    ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);

    secp256k1_nonce_function noncefn = secp256k1_nonce_function_rfc6979;
    void* data_ = NULL;

    secp256k1_ecdsa_recoverable_signature signature;
    memset(&signature, 0, sizeof(signature));
    if (!secp256k1_ecdsa_sign_recoverable(ctx, &signature, message_hash,  private_key, noncefn, data_)) {
        secp256k1_context_destroy(ctx);
        return 0;
    }

    // Should be safe to cast rec_id to int
    // I have no idea why rec_id is int,
    // because we will write only one byte to it *recid = sig->data[64];
    if (!secp256k1_ecdsa_recoverable_signature_serialize_compact(ctx, output, (int *)rec_id, &signature)){
        secp256k1_context_destroy(ctx);
        return 0;
    }

    secp256k1_context_destroy(ctx);
    return 1;
}


void loop() {
  if (Serial.available()) {  // Check if data is available
        uint8_t cmd_input;
        size_t len = Serial.readBytes(&cmd_input, 1);

        if (len > 0) {
            switch (cmd_input) {
                case CMD_CHECK_STATUS:
                {
                    uint8_t response_ok = RESPONSE_OK;
                    Serial.write(&response_ok, 1);
                    break;
                }
                case CMD_GET_PUBKEY:
                {
                    uint8_t key_hash[32];
                    size_t len = Serial.readBytes(key_hash, 32);

                    if (len != 32) {
                        break;
                    }

                    uint8_t private_key[32];
                    decrypt_private_key(key_hash, private_key);

                    uint8_t public_key[65] = {0};
                    int response = get_public_key(private_key, public_key);

                    memcpy(private_key, ZEROS, 32);

                    uint8_t response_ok[66];
                    if (response) {
                        response_ok[0] = RESPONSE_OK;
                    } else {
                        response_ok[0] = RESPONSE_FAIL;
                    }
                    response_ok[0] = RESPONSE_OK;
                    memcpy(response_ok+1, public_key, 65);

                    Serial.write(response_ok, 66);

                    break;
                }
                case CMD_SIGN:
                {
                    uint8_t key_hash[32];
                    size_t len = Serial.readBytes(key_hash, 32);
                    if (len != 32) break;

                    uint8_t private_key[32];
                    decrypt_private_key(key_hash, private_key);

                    uint8_t message_len_bytes[2];
                    len = Serial.readBytes(message_len_bytes, 2);

                    if (len != 2) {
                        uint8_t output[1] = {ERROR_WRONG_DATA_FORMAT};
                        Serial.write(output, 1);
                        return;
                    }

                    // Convert 2 bytes to uint16_t (big-endian)
                    uint16_t message_len = (message_len_bytes[0] << 8) | message_len_bytes[1];

                    if (message_len == 0 || message_len > 1024) {
                        uint8_t output[1] = {ERROR_WRONG_DATA_FORMAT};
                        Serial.write(output, 1);
                        return;
                    }
                    // Read message of `message_len` bytes
                    uint8_t* message = new uint8_t[message_len];
                    size_t actual_len = Serial.readBytes(message, message_len);

                    if (actual_len != message_len) {
                        delete[] message;
                        uint8_t output[1] = {ERROR_WRONG_DATA_FORMAT};
                        Serial.write(output, 1);
                        return;
                    }

                    uint8_t message_hash[32] = {0};
                    keccak256(message, message_len, message_hash);

                    // Remember to free heap memory
                    delete[] message;

                    uint8_t signature[64] = {0};
                    uint8_t rec_id[1] = {0};
                    int response = sign(private_key, message_hash, signature, rec_id);

                    memcpy(private_key, ZEROS, 32);

                    uint8_t response_ok[66];
                    if (response) {
                        response_ok[0] = RESPONSE_OK;
                    } else {
                        response_ok[0] = RESPONSE_FAIL;
                    }
                    memcpy(response_ok+1, signature, 64);
                    memcpy(response_ok+65, &rec_id, 1);

                    Serial.write(response_ok, 66);
                    break;
                }
                default:
                {
                    uint8_t response_err = ERROR_WRONG_CMD;
                    Serial.write(&response_err, 1);
                }
            }
        }
    }

    delay(1000);
}