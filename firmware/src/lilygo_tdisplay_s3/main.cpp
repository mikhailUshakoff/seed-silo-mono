#include <TFT_eSPI.h>
//#include <SHA256.h>
#include <stdio.h>
#include <mbedtls/aes.h>
#include <uECC.h> // Micro-ECC library
#include <KeccakCore.h>
#include <input.h>

#include "constants.h"
#include <core/command_handlers.h>

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
                case CMD_GET_VERSION:
                {
                    tft.drawString("CMD: check status1",10,10);
                    handle_get_version_cmd();
                    break;
                }
                case CMD_GET_PUBKEY:
                {
                    tft.drawString("CMD: get public key",10,10);
                    handle_get_pubkey_cmd();
                    break;
                }
                case CMD_SIGN:
                {
                    tft.drawString("CMD: sign",10,10);
                    handle_sign_cmd();
                    break;
                }
                default:
                {
                    tft.drawString("CMD: unknown",10,30);
                    uint8_t response_err = ERROR_WRONG_CMD;
                    Serial.write(&response_err, 1);
                }
            }
        } else {
            tft.drawString("SERIAL: no data",10,30);
        }
    }

    delay(1000);
}
