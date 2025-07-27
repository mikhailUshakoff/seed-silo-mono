#include <TFT_eSPI.h>
//#include <SHA256.h>
#include <stdio.h>
#include <mbedtls/aes.h>
#include <uECC.h> // Micro-ECC library
#include <KeccakCore.h>
#include <input.h>

#include "constants.h"
#include "core/core.h"

TFT_eSPI tft = TFT_eSPI();
TFT_eSprite sprite = TFT_eSprite(&tft);

#define down 0
#define up 14

void setup() {  //.......................setup

    Serial.begin(115200);

    pinMode(down,INPUT_PULLUP);
    pinMode(up,INPUT_PULLUP);
    tft.init();
    tft.setRotation(1);
    tft.fillScreen(TFT_BLACK);

    tft.setTextColor(TFT_WHITE,TFT_BLACK);

    tft.drawString("Hello World!",10,10);
}

void loop() { //...............................................................loop
    if (Serial.available()) {  // Check if data is available
        // clear screen
        tft.fillScreen(TFT_BLACK);

        uint8_t cmd_input;
        size_t len = Serial.readBytes(&cmd_input, 1);

        if (len > 0) {
            switch (cmd_input) {
                case CMD_CHECK_STATUS:
                {
                    tft.drawString("CMD: check status1",10,10);
                    uint8_t response_ok = RESPONSE_OK;
                    Serial.write(&response_ok, 1);
                    break;
                }
                case CMD_GET_PUBKEY:
                {
                    tft.drawString("CMD: get public key",10,10);

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
                    tft.drawString("CMD: sign",10,10);

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
                    tft.drawString("CMD: error",10,30);
                    uint8_t response_err = ERROR_WRONG_CMD;
                    Serial.write(&response_err, 1);
                }
            }
        }
    }

    delay(1000);
}
