#include <cstdint>
#include <mbedtls/aes.h>
#include <input.h>

#include "secp256k1_recovery.h"
#include "secp256k1_c.h"
#include "module/recovery/main_impl.h"

extern "C" {
    #include "sha3.h"
}

void keccak256(uint8_t* input, size_t input_len, uint8_t* output) {
    sha3_keccak(input, input_len, output, 32);
}

void decrypt_private_key(uint8_t *key, uint8_t *output) {
    mbedtls_aes_context aes;
    mbedtls_aes_init(&aes);

    // Set AES key (256-bit)
    mbedtls_aes_setkey_enc(&aes, key, 256);

    // Set AES IV
    unsigned char iv[16] = AES_IV_INITIALIZER;

    // Set encrypted data
    unsigned char encrypted_data[48] = ENCRYPTED_DATA_INITIALIZER;

    // Print decrypted data
    mbedtls_aes_crypt_cbc(&aes, MBEDTLS_AES_DECRYPT, 48, iv, encrypted_data, output);

    // Clean up
    mbedtls_aes_free(&aes);
}

// get public key
// 1 - success
// 0 - fail
int get_public_key(uint8_t *private_key, uint8_t *output) {
    secp256k1_context *ctx;
    ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);

    secp256k1_pubkey pubkey;
    if (!secp256k1_ec_pubkey_create(ctx, &pubkey, private_key)) {
        secp256k1_context_destroy(ctx);
        return 0;
    }

    size_t len = 65;
    if (!secp256k1_ec_pubkey_serialize(ctx, output, &len, &pubkey, SECP256K1_EC_UNCOMPRESSED)) {
        secp256k1_context_destroy(ctx);
        return 0;
    }

    secp256k1_context_destroy(ctx);
    return 1;
}


// sign
// 1 - success
// 0 - fail
int sign(uint8_t* private_key, uint8_t* message_hash, uint8_t* output, uint8_t* rec_id) {
    secp256k1_context *ctx;
    ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);

    secp256k1_nonce_function noncefn = secp256k1_nonce_function_rfc6979;
    void* data_ = NULL;

    secp256k1_ecdsa_recoverable_signature signature;
    memset(&signature, 0, sizeof(signature));
    if (!secp256k1_ecdsa_sign_recoverable(ctx, &signature, message_hash,  private_key, noncefn, data_)) {
        secp256k1_context_destroy(ctx);
        return 0;
    }

    // Should be safe to cast rec_id to int
    // I have no idea why rec_id is int,
    // because we will write only one byte to it *recid = sig->data[64];
    if (!secp256k1_ecdsa_recoverable_signature_serialize_compact(ctx, output, (int *)rec_id, &signature)){
        secp256k1_context_destroy(ctx);
        return 0;
    }

    secp256k1_context_destroy(ctx);
    return 1;
}
