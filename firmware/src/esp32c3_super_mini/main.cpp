#include <Arduino.h>
#include <core/command_handlers.h>

void setup() {  //.......................setup
    Serial.begin(115200);
}

void loop() {
  if (Serial.available()) {  // Check if data is available
        uint8_t cmd_input;
        size_t len = Serial.readBytes(&cmd_input, 1);

        if (len > 0) {
            switch (cmd_input) {
                case CMD_GET_VERSION:
                {
                    handle_get_version_cmd();
                    break;
                }
                case CMD_GET_PUBKEY:
                {
                    handle_get_pubkey_cmd();
                    break;
                }
                case CMD_SIGN:
                {
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
                    if (result != CORE_SUCCESS) {
                        error_response(result);
                        return;
                    }
                    sign_cmd_response(signature, rec_id);
                    secure_memzero(signature, 64);
                    rec_id = 0;

                    break;
                }
                default:
                {
                    uint8_t response_err = CORE_ERR_UNKNOWN_CMD;
                    Serial.write(&response_err, 1);
                }
            }
        }
    }

    delay(1000);
}