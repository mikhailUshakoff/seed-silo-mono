#include <Arduino.h>
#include <mbedtls/aes.h>
#include <uECC.h> // Micro-ECC library
#include <KeccakCore.h>

#include "secp256k1/include/secp256k1_recovery.h"
#include "secp256k1/src/secp256k1_c.h"
#include "secp256k1/src/module/recovery/main_impl.h"
#include "input.h"

#define CMD_CHECK_STATUS 0x01
#define CMD_GET_PUBKEY 0x02
#define CMD_SIGN 0x03

#define RESPONSE_OK 0xF0
#define ERROR_WRONG_CMD 0x01

#define uECC_SUPPORTS_secp256k1 1

uint8_t ZEROS[32] = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

void setup() {  //.......................setup
    Serial.begin(115200);
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

void get_public_key(uint8_t *private_key, uint8_t *output) {
    uECC_compute_public_key(private_key, output, uECC_secp256k1());
    // TODO secp256k1_ec_pubkey_create
}

void sign(uint8_t* private_key, uint8_t* message_hash, uint8_t* output, uint8_t* rec_id) {
    secp256k1_context *ctx;
    ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);

    secp256k1_nonce_function noncefn = secp256k1_nonce_function_rfc6979;
    void* data_ = NULL;

    secp256k1_ecdsa_recoverable_signature signature;
    memset(&signature, 0, sizeof(signature));
    if (secp256k1_ecdsa_sign_recoverable(ctx, &signature, message_hash,  private_key, noncefn, data_) == 0) {
        return;
    }

    // Should be safe to cast rec_id to int
    // I have no idea why rec_id is int,
    // because we will write only one byte to it *recid = sig->data[64];
    secp256k1_ecdsa_recoverable_signature_serialize_compact(ctx, output, (int *)rec_id, &signature);
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

                    uint8_t public_key[64];
                    get_public_key(private_key, public_key);

                    memcpy(private_key, ZEROS, 32);

                    uint8_t response_ok[65];
                    response_ok[0] = RESPONSE_OK;
                    memcpy(response_ok+1, public_key, 64);

                    Serial.write(response_ok, 65);

                    break;
                }
                case CMD_SIGN:
                {
                    uint8_t key_hash[32];
                    size_t len = Serial.readBytes(key_hash, 32);
                    if (len != 32) break;

                    uint8_t private_key[32];
                    decrypt_private_key(key_hash, private_key);

                    uint8_t message_hash[32];
                    len = Serial.readBytes(message_hash, 32);
                    if (len != 32) break;

                    uint8_t signature[64] = {0}; // TODO 64
                    uint8_t rec_id[1] = {0};
                    sign(private_key, message_hash, signature, rec_id);

                    memcpy(private_key, ZEROS, 32);

                    uint8_t response_ok[66];
                    response_ok[0] = RESPONSE_OK;
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