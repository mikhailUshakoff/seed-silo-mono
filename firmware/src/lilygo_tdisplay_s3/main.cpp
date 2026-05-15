#include <TFT_eSPI.h>
#include <core/command_handlers.h>
#include "print_eip1559_tx.h"
#include <rlp_decoder.h>

TFT_eSPI tft = TFT_eSPI();
TFT_eSprite sprite = TFT_eSprite(&tft);

#define down 0
#define up 14

bool bSignConfirmationScreen = false;
uint8_t signature[64] = {0};
int rec_id = 0;
uint8_t message[MAX_MSG_LEN];
uint16_t msg_len = 0;

void clear_message() {
    secure_memzero(message, msg_len);
    msg_len = 0;
}

void clear_signature() {
    secure_memzero(signature, sizeof(signature));
    rec_id = 0;
}

void drawSignConfirmationUI() {
    // display: 320, 170
    // draw approve icon
    tft.fillRect(290, 10, 20, 20, TFT_GREEN);
    tft.drawWideLine(298, 26, 306, 14, 3, TFT_BLACK);
    tft.drawWideLine(298, 26, 294, 18, 3, TFT_BLACK);
    // draw reject icon
    tft.fillRect(290, 140, 20, 20, TFT_RED);
    tft.drawWideLine(294, 144, 306, 156, 3, TFT_BLACK);
    tft.drawWideLine(294, 156, 306, 144, 3, TFT_BLACK);
}

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

    if(digitalRead(up)==0 && bSignConfirmationScreen){
        bSignConfirmationScreen = false;
        // clear screen
        tft.fillScreen(TFT_BLACK);
        tft.drawString("TX Approved",10,10);
        sign_cmd_response(signature, rec_id);
        clear_signature();
    }

    if(digitalRead(down)==0 && bSignConfirmationScreen){
        bSignConfirmationScreen = false;
        // clear screen
        tft.fillScreen(TFT_BLACK);
        clear_signature();
        tft.drawString("TX Rejected",10,10);
        uint8_t response = CORE_ERR_TX_REJECTED;
        Serial.write(&response, 1);
    }

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
                    tft.drawString("CMD: sign",5,5);

                    int result = sign_cmd_get_msg_signature(
                        signature,
                        &rec_id,
                        message,
                        &msg_len
                    );
                    if (result != CORE_SUCCESS) {
                        clear_message();
                        clear_signature();
                        error_response(result);
                        return;
                    }

                    result = print_eip1559_tx(message, msg_len);
                    clear_message();
                    if (result != CORE_SUCCESS) {               
                        clear_signature();
                        error_response(result);
                        return;
                    }

                    bSignConfirmationScreen = true;

                    drawSignConfirmationUI();

                    break;
                }
                default:
                {
                    tft.drawString("CMD: unknown",10,30);
                    uint8_t response_err = CORE_ERR_UNKNOWN_CMD;
                    Serial.write(&response_err, 1);
                }
            }
        } else {
            tft.drawString("SERIAL: no data",10,30);
        }
    }

    delay(1000);
}

