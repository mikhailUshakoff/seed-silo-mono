#include <mbedtls/aes.h>
#include "../input.h"
#include "../constants.h"

int decrypt_private_key(uint8_t *key, byte pos, uint8_t *output) {
    // Validate input parameters
    if (!key || !output) {
        return CORE_ERR_INVALID_PARAMS;
    }

    if (pos > DECRYPTED_DATA_LEN - 32) {
        return CORE_ERR_INVALID_POSITION;
    }

    // Initialize AES context
    mbedtls_aes_context aes;
    mbedtls_aes_init(&aes);

    // Set AES key (256-bit)
    int ret = mbedtls_aes_setkey_enc(&aes, key, 256);
    if (ret != 0) {
        mbedtls_aes_free(&aes);
        return CORE_ERR_KEY_SETUP;
    }

    // Set AES IV
    unsigned char iv[16] = AES_IV_INITIALIZER;

    // Set encrypted data
    unsigned char encrypted_data[ENCRYPTED_DATA_LEN] = ENCRYPTED_DATA_INITIALIZER;
    // Buffer for decrypted data
    unsigned char decrypted_data[DECRYPTED_DATA_LEN] = {0};
    // Print decrypted data
    ret = mbedtls_aes_crypt_cbc(&aes, MBEDTLS_AES_DECRYPT, ENCRYPTED_DATA_LEN, iv, encrypted_data, decrypted_data);

    // Clean up
    mbedtls_aes_free(&aes);

    if (ret != 0) {
        return CORE_ERR_DECRYPTION;
    }

    // Copy the relevant 32-byte segment to output
    memcpy(output, decrypted_data + pos, 32);

    return CORE_SUCCESS;
}