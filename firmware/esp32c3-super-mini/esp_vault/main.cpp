#include <Arduino.h>
#include <mbedtls/aes.h>
#include <uECC.h> // Micro-ECC library
#include <KeccakCore.h>

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

int esp32_rng(uint8_t *dest, unsigned size) {
    while (size > 0) {
        uint32_t random_value = esp_random(); // Generate a 32-bit random number
        uint8_t bytes[4];
        bytes[0] = random_value & 0xFF;
        bytes[1] = (random_value >> 8) & 0xFF;
        bytes[2] = (random_value >> 16) & 0xFF;
        bytes[3] = (random_value >> 24) & 0xFF;

        for (int i = 0; i < 4 && size > 0; i++) {
            *dest++ = bytes[i];
            size--;
        }
    }
    return 1; // Return 1 to indicate success
}

void setup() {  //.......................setup
    Serial.begin(115200);

    uECC_set_rng(&esp32_rng);
}

void decrypt_private_key(uint8_t *key, uint8_t *output) {
    mbedtls_aes_context aes;
    mbedtls_aes_init(&aes);

    // Set AES key (256-bit)
    mbedtls_aes_setkey_enc(&aes, key, 256);

    // Set AES IV
    unsigned char iv[16] = {...};
    unsigned char encrypted_data[48] = {
        ...
    };

    // Print decrypted data
    mbedtls_aes_crypt_cbc(&aes, MBEDTLS_AES_DECRYPT, 48, iv, encrypted_data, output);

    // Clean up
    mbedtls_aes_free(&aes);
}

void get_public_key(uint8_t *private_key, uint8_t *output) {
    uECC_compute_public_key(private_key, output, uECC_secp256k1());
}

void sign(uint8_t* private_key, uint8_t* message_hash, uint8_t* output) {
    int success = uECC_sign(private_key, message_hash, 32, output, uECC_secp256k1());
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

                    uint8_t signature[64]; // TODO 64
                    sign(private_key, message_hash, signature);

                    memcpy(private_key, ZEROS, 32);

                    uint8_t response_ok[65];
                    response_ok[0] = RESPONSE_OK;
                    memcpy(response_ok+1, signature, 64);

                    Serial.write(response_ok, 65);
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