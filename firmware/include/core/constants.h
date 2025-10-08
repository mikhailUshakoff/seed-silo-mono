#ifndef CONSTANTS_H
#define CONSTANTS_H

    #define CMD_GET_VERSION 0x01
    #define CMD_GET_PUBKEY 0x02
    #define CMD_SIGN 0x03

    // Universal error codes for crypto operations
    #define CORE_SUCCESS                0x00 // Operation completed successfully
    #define CORE_ERR_UNKNOWN_CMD        0x01 // Unrecognized command
    #define CORE_ERR_WRONG_DATA_FORMAT  0x02 // Input data format is incorrect
    #define CORE_ERR_WRONG_RECOVERY_ID  0x03 // Recovery ID is out of valid range
    #define CORE_ERR_INVALID_PARAMS     0x04 // NULL pointer passed for parameters
    #define CORE_ERR_INVALID_POSITION   0x05 // Position exceeds valid range
    #define CORE_ERR_KEY_SETUP          0x06 // Failed to set up encryption key
    #define CORE_ERR_DECRYPTION         0x07 // Decryption operation failed
    #define CORE_ERR_PUBKEY_CREATE      0x08 // Failed to create public key
    #define CORE_ERR_PUBKEY_SERIALIZE   0x09 // Failed to serialize public key
    #define CORE_ERR_SIGN_FAILED        0x0a // Failed to create signature
    #define CORE_ERR_SERIALIZE_FAILED   0x0b // Failed to serialize signature
    #define CORE_ERR_TX_REJECTED        0x0c // Transaction was rejected by user
    #define CORE_ERR_NOT_TYPE2_TX       0x0d // Not a type-2 (EIP-1559) transaction
    #define CORE_ERR_RLP_LIST_PARSE     0x0e // Failed to parse RLP list structure
    #define CORE_ERR_RLP_LIST_LENGTH    0x0f // RLP list length is invalid
    #define CORE_ERR_RLP_FIELD_PARSE    0x10 // Failed to parse RLP field
    #define CORE_ERR_NOT_EIP20_TRANSFER 0x11 // Transaction data is not EIP-20 transfer

    unsigned char ZEROS[32] = {
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    };
#endif // CONSTANTS_H