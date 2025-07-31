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

int sign_cmd_get_msg_signature123(
    uint8_t* out_signature,
    uint8_t* out_rec_id,
    uint8_t* out_message,
    uint16_t* out_msg_len
) {
    uint8_t key[32];
    if (Serial.readBytes(key, sizeof(key)) != sizeof(key)) {
        error_response(ERROR_WRONG_DATA_FORMAT);
        return STATUS_ERR;
    }

    uint8_t private_key[32];
    decrypt_private_key(key, private_key);
    secure_memzero(key, sizeof(key));

    uint8_t len_bytes[2];
    if (Serial.readBytes(len_bytes, 2) != 2) {
        secure_memzero(private_key, sizeof(private_key));
        error_response(ERROR_WRONG_DATA_FORMAT);
        return STATUS_ERR;
    }

    *out_msg_len = (len_bytes[0] << 8) | len_bytes[1];
    if (*out_msg_len == 0 || *out_msg_len > MAX_MSG_LEN) {
        error_response(ERROR_WRONG_DATA_FORMAT);
        secure_memzero(private_key, sizeof(private_key));
        return STATUS_ERR;
    }

    if (Serial.readBytes(out_message, *out_msg_len) != *out_msg_len) {
        error_response(ERROR_WRONG_DATA_FORMAT);
        secure_memzero(private_key, sizeof(private_key));
        return STATUS_ERR;
    }

    uint8_t hash[32] = {0};
    size_t len = *out_msg_len;
    keccak256(out_message, len, hash);
    tft.println(*out_msg_len);

    int success = sign(private_key, hash, out_signature, out_rec_id);
    tft.println(*out_msg_len);
    tft.println(len);
    secure_memzero(private_key, sizeof(private_key));
    tft.println(*out_msg_len);
    if (!success) {
        error_response(RESPONSE_FAIL);
        return STATUS_ERR;
    }

    tft.println(*out_msg_len);

    return STATUS_OK;
}

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

// Main parser: parse EIP-1559 type-2 tx and print all fields
void parse_eip1559_tx(const uint8_t *tx, uint16_t len) {
    if (len < 2 || tx[0] != 0x02) {
        tft.drawString("Not a type-2 tx", 10, 15);
        print_hex_tft("tx", tx, len, 10, 30);
        char buf[10] = {0};
        snprintf(buf, sizeof(buf), "%02x", tx[0]);
        tft.drawString(buf, 10, 40);
        return;
    }

    const uint8_t *rlp = tx + 1;
    size_t rlp_len = len - 1;

    size_t list_len = 0, list_offset = 0;
    if (rlp_read_length(rlp, rlp_len, &list_len, &list_offset) != 0) {
        tft.drawString("RLP list parse fail", 10, 15);
        return;
    }

    if (list_offset + list_len > rlp_len) {
        tft.drawString("RLP list length invalid", 10, 15);
        return;
    }

    const uint8_t *p = rlp + list_offset;
    size_t remaining = list_len;

    const char *fields[] = {
        "chain_id", "nonce", "max_priority_fee_per_gas", "max_fee_per_gas",
        "gas_limit", "to", "value", "data", "access_list",
        "v", "r", "s"
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
            return;
        }

        if (i == 8) {
            // access_list is complex; skip decoding here
            tft.drawString("access_list: <skipped>", x, y);
        } else {
            print_hex_tft(fields[i], field, field_len, x, y);
        }

        p += consumed;
        remaining -= consumed;
        y += line_height;
    }
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

    if(digitalRead(up)==0){
        tft.drawString("UP",10,50);
        // Your RLP-encoded EIP-1559 tx bytes (example)
    const uint8_t tx[] = {
        0x02, 0xee, 0x82, 0x42, 0x68, 0x1a, 0x83, 0x0f, 0x42, 0x40, 0x83, 0x16, 0xe3, 0x69, 0x82,
        0x52, 0x08, 0x94, 0x97, 0xed, 0x1e, 0x9f, 0x67, 0x1a, 0x7e, 0xd3, 0xa6, 0x17, 0x3e, 0x7d,
        0x74, 0x39, 0x36, 0xbb, 0x9c, 0xb2, 0xe1, 0x88, 0x87, 0x03, 0x8d, 0x7e, 0xa4, 0xc6, 0x80,
        0x00, 0x80, 0xc0
    };

    parse_eip1559_tx(tx, sizeof(tx));
    }

    if(digitalRead(down)==0 && bSignConfirmationScreen){
        tft.drawString("DOWN",10,58);
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
                    uint8_t signature[64] = {0};
                    uint8_t rec_id = 0;

                    int result = sign_cmd_get_msg_signature123(
                        signature,
                        &rec_id,
                        message,
                        &msg_len
                    );

                    if (result != STATUS_OK) return;

                    parse_eip1559_tx(message, msg_len);
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

