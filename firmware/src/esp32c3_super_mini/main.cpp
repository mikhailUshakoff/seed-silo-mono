#include <Arduino.h>
#include <core/command_handlers.h>

// ============================================================================
// Command Handlers
// ============================================================================

void handle_sign_command() {
                    uint8_t signature[64] = {0};
                    int rec_id = 0;
                    uint8_t message[MAX_MSG_LEN];
                    uint16_t msg_len = 0;

                    int result = sign_cmd_get_msg_signature(
                        signature,
                        &rec_id,
                        message,
                        &msg_len
                    );

                    secure_memzero(message, msg_len);
                    msg_len = 0;

                    if (result != CORE_SUCCESS) {
        secure_memzero(signature, sizeof(signature));
                        rec_id = 0;    
                        error_response(result);
                        return;
                    }

                    sign_cmd_response(signature, rec_id);
    secure_memzero(signature, sizeof(signature));
                    rec_id = 0;
                }

void handle_serial_command(uint8_t cmd_input) {
    switch (cmd_input) {
        case CMD_GET_VERSION:
            handle_get_version_cmd();
            break;

        case CMD_GET_PUBKEY:
            handle_get_pubkey_cmd();
            break;

        case CMD_SIGN:
            handle_sign_command();
            break;

        default: {
            uint8_t response_err = CORE_ERR_UNKNOWN_CMD;
            Serial.write(&response_err, 1);
            }
        }
    }

// ============================================================================
// Setup and Loop
// ============================================================================

void setup() {
    Serial.begin(115200);
}

void loop() {
    if (Serial.available()) {  // Check if data is available
        uint8_t cmd_input;
        size_t len = Serial.readBytes(&cmd_input, 1);

        if (len > 0) {
            handle_serial_command(cmd_input);
        }
    }

    delay(1000);
}
