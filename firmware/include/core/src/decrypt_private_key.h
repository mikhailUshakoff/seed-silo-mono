#include <cstdint>
#include <mbedtls/aes.h>
#include <input.h>

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