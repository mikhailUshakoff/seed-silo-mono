#include <cstdint>
#include <mbedtls/aes.h>
#include <input.h>

void decrypt_private_key(uint8_t *key, byte pos, uint8_t *output) {
    mbedtls_aes_context aes;
    mbedtls_aes_init(&aes);

    // Set AES key (256-bit)
    mbedtls_aes_setkey_enc(&aes, key, 256);

    // Set AES IV
    unsigned char iv[16] = AES_IV_INITIALIZER;

    // Set encrypted data
    unsigned char encrypted_data[ENCRYPTED_DATA_LEN] = ENCRYPTED_DATA_INITIALIZER;
    // Buffer for decrypted data
    unsigned char decrypted_data[DECRYPTED_DATA_LEN] = {0};
    // Print decrypted data
    mbedtls_aes_crypt_cbc(&aes, MBEDTLS_AES_DECRYPT, ENCRYPTED_DATA_LEN, iv, encrypted_data, decrypted_data);

    // Clean up
    mbedtls_aes_free(&aes);

    // Copy the relevant 32-byte segment to output
    if (pos < 0 || pos > DECRYPTED_DATA_LEN - 32) {
        return;
    }

    memcpy(output, decrypted_data + pos, 32);

}