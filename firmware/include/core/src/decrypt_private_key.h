#include <mbedtls/gcm.h>
#include "../input.h"
#include "../constants.h"
#include "secure_memzero.h"

int decrypt_private_key(uint8_t *key, byte pos, uint8_t *output) {
    // Validate input parameters
    if (!key || !output) {
        return CORE_ERR_INVALID_PARAMS;
    }

    if (pos > DECRYPTED_DATA_LEN - 32) {
        return CORE_ERR_INVALID_POSITION;
    }

    // Initialize AES context
    mbedtls_gcm_context aes;
    mbedtls_gcm_init(&aes);

    // Set AES key (256-bit)
    int ret = mbedtls_gcm_setkey(&aes, MBEDTLS_CIPHER_ID_AES, key, 256);
    if (ret != 0) {
        mbedtls_gcm_free(&aes);
        return CORE_ERR_KEY_SETUP;
    }

    // Set AES IV
    unsigned char iv[GCM_IV_LEN] = GCM_IV_INITIALIZER;
    // Set AES GCM tag
    unsigned char tag[GCM_TAG_LEN] = GCM_TAG_INITIALIZER;

    // Set encrypted data
    unsigned char encrypted_data[ENCRYPTED_DATA_LEN] = ENCRYPTED_DATA_INITIALIZER;
    // Buffer for decrypted data
    unsigned char decrypted_data[DECRYPTED_DATA_LEN] = {0};
    // Print decrypted data
    ret = mbedtls_gcm_auth_decrypt(&aes, ENCRYPTED_DATA_LEN, iv, sizeof(iv), NULL, 0, tag, sizeof(tag), encrypted_data, decrypted_data);

    // Clean up
    mbedtls_gcm_free(&aes);

    if (ret != 0) {
        secure_memzero(decrypted_data, sizeof(decrypted_data));
        return CORE_ERR_DECRYPTION;
    }

    // Copy the relevant 32-byte segment to output
    memcpy(output, decrypted_data + pos, 32);

    // Zero decrypted data after use
    secure_memzero(decrypted_data, sizeof(decrypted_data));

    return CORE_SUCCESS;
}