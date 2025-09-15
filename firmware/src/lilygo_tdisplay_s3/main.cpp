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

bool bSignConfirmationScreen = false;
uint8_t signature[64] = {0};
int rec_id = 0;

void tft_drawString(const char* str, int x, int y) {
    // For demo, just print with coordinates
    printf("TFT @(%d,%d): %s\n", x, y, str);
}

// RLP length decode: handles strings and lists (short and long)
int rlp_read_length(const uint8_t *data, size_t data_len, size_t *out_len, size_t *out_offset) {
    if (data_len == 0) return -1;

    uint8_t prefix = data[0];

    if (prefix <= 0x7f) {
        *out_len = 1;
        *out_offset = 0;
        return 0;
    } else if (prefix <= 0xb7) {
        size_t len = prefix - 0x80;
        if (len > data_len - 1) return -1;
        *out_len = len;
        *out_offset = 1;
        return 0;
    } else if (prefix <= 0xbf) {
        size_t len_of_len = prefix - 0xb7;
        if (len_of_len + 1 > data_len) return -1;
        size_t len = 0;
        for (size_t i = 0; i < len_of_len; i++) {
            len = (len << 8) | data[1 + i];
        }
        if (len + len_of_len + 1 > data_len) return -1;
        *out_len = len;
        *out_offset = 1 + len_of_len;
        return 0;
    } else if (prefix <= 0xf7) {
        size_t len = prefix - 0xc0;
        if (len > data_len - 1) return -1;
        *out_len = len;
        *out_offset = 1;
        return 0;
    } else if (prefix <= 0xff) {
        size_t len_of_len = prefix - 0xf7;
        if (len_of_len + 1 > data_len) return -1;
        size_t len = 0;
        for (size_t i = 0; i < len_of_len; i++) {
            len = (len << 8) | data[1 + i];
        }
        if (len + len_of_len + 1 > data_len) return -1;
        *out_len = len;
        *out_offset = 1 + len_of_len;
        return 0;
    }

    return -1;
}

// Reads a single RLP item (string or list element) from data buffer
const uint8_t* rlp_read_item(const uint8_t *data, size_t data_len, size_t *item_len, size_t *consumed) {
    size_t len = 0, offset = 0;
    if (rlp_read_length(data, data_len, &len, &offset) != 0) return NULL;
    if (offset + len > data_len) return NULL;
    *item_len = len;
    *consumed = offset + len;
    return data + offset;
}

// Utility: Print hex to TFT (or console here) with label at (x,y)
void print_hex_tft(const char *label, const uint8_t *data, size_t len, int x, int y) {
    char buf[256] = {0};
    int written = snprintf(buf, sizeof(buf), "%s: 0x", label);
    for (size_t i = 0; i < len && written < (int)(sizeof(buf) - 3); i++) {
        written += snprintf(buf + written, sizeof(buf) - written, "%02x", data[i]);
    }
    tft.drawString(buf, x, y);
}

void print_hex_tft_trim_leading_zeros(const char *label, const uint8_t *data, size_t len, int x, int y) {
    char buf[256] = {0};
    int written = snprintf(buf, sizeof(buf), "%s: 0x", label);

    size_t start = 0;
    while (start < len && data[start] == 0) {
        start++;
    }

    for (size_t i = start; i < len && written < (int)(sizeof(buf) - 3); i++) {
        written += snprintf(buf + written, sizeof(buf) - written, "%02x", data[i]);
    }

    if (start == len) {
        written += snprintf(buf + written, sizeof(buf) - written, "0");
    }

    tft.drawString(buf, x, y);
}

// Main parser: parse EIP-1559 type-2 tx and print all fields
int parse_eip1559_tx(const uint8_t *tx, uint16_t len) {
    if (len < 2 || tx[0] != 0x02) {
        tft.drawString("Not a type-2 tx", 10, 15);
        print_hex_tft("tx", tx, len, 10, 30);
        return STATUS_ERR;
    }

    const uint8_t *rlp = tx + 1;
    size_t rlp_len = len - 1;

    size_t list_len = 0, list_offset = 0;
    if (rlp_read_length(rlp, rlp_len, &list_len, &list_offset) != 0) {
        tft.drawString("RLP list parse fail", 10, 15);
        return STATUS_ERR;
    }

    if (list_offset + list_len > rlp_len) {
        tft.drawString("RLP list length invalid", 10, 15);
        return STATUS_ERR;
    }

    const uint8_t *p = rlp + list_offset;
    size_t remaining = list_len;

    const char *fields[] = {
        "chain_id", "nonce", "max_priority_fee_per_gas", "max_fee_per_gas",
        "gas_limit", "to", "value", "data"
    };
    int num_fields = sizeof(fields) / sizeof(fields[0]);

    int x = 10;
    int y = 15;
    int line_height = 10;

    for (int i = 0; i < num_fields && remaining > 0; i++) {
        size_t field_len = 0, consumed = 0;
        const uint8_t *field = rlp_read_item(p, remaining, &field_len, &consumed);
        if (!field) {
            tft.drawString("RLP field parse fail", x, y);
            return STATUS_ERR;
        }

        if (i == 7 && field_len > 0) {
            if (field_len != 4 + 32 + 32 || memcmp(field, "\xa9\x05\x9c\xbb", 4) != 0) {
                tft.drawString("Not EIP-20 transfer", x, y);
                return STATUS_ERR;
            }

            const uint8_t *to_address = field + 4 + 12; // skip function selector + padding
            const uint8_t *amount = field + 4 + 32;

            tft.drawString("EIP-20 transfer (0xa9059cbb)", x, y);
            y += line_height;
            print_hex_tft("to", to_address, 20, x, y);
            y += line_height;

            print_hex_tft_trim_leading_zeros("amount", amount, 32, x, y);
        } else {
            print_hex_tft(fields[i], field, field_len, x, y);
        }

        p += consumed;
        remaining -= consumed;
        y += line_height;
    }

    // Print remaining bytes if any
    if (remaining > 0) {
        print_hex_tft("remaining", p, remaining, x, y);
    }

    return STATUS_OK;
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
        int result = sign_cmd_response(signature, rec_id);
        if (result != STATUS_OK) {
            tft.drawString("Wrong Recovery ID",10,20);
        }
        secure_memzero(signature, 64);
        rec_id = 0;
    }

    if(digitalRead(down)==0 && bSignConfirmationScreen){
        bSignConfirmationScreen = false;
        // clear screen
        tft.fillScreen(TFT_BLACK);
        secure_memzero(signature, 64);
        rec_id = 0;
        tft.drawString("TX Rejected",10,10);
        uint8_t response = RESPONSE_FAIL;
        Serial.write(&response, 1);
    }

    if(bSignConfirmationScreen){
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
                    //handle_sign_cmd();
                    uint8_t message[MAX_MSG_LEN];
                    uint16_t msg_len = 0;

                    int result = sign_cmd_get_msg_signature(
                        signature,
                        &rec_id,
                        message,
                        &msg_len
                    );
                    if (result != STATUS_OK) return;

                    result = parse_eip1559_tx(message, msg_len);
                    if (result != STATUS_OK) return;

                    bSignConfirmationScreen = true;

                    //sign_cmd_response(signature, &rec_id);
                    /*uint8_t private_key[32];
                    uint8_t message[MAX_MSG_LEN];
                    uint16_t msg_len = 0;

                    if (decode_sign_data(private_key, message, &msg_len) == STATUS_ERR) {
                        return;
                    }
                    parse_eip1559_tx(message, msg_len);
                    bSignConfirmationScreen = true;*/
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

