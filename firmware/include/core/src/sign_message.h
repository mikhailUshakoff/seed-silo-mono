#include "secp256k1_recovery.h"
#include "secp256k1_c.h"
#include "module/recovery/main_impl.h"
#include "../constants.h"

extern "C" {
    #include "sha3.h"
}

void keccak256(uint8_t* input, size_t input_len, uint8_t* output) {
    sha3_keccak(input, input_len, output, 32);
}

// sign message hash
int sign(uint8_t* private_key, uint8_t* message_hash, uint8_t* output, int* rec_id) {
    // Validate input parameters
    if (!private_key || !message_hash || !output || !rec_id) {
        return CORE_ERR_INVALID_PARAMS;
    }

    secp256k1_context *ctx;
    ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);

    secp256k1_nonce_function noncefn = secp256k1_nonce_function_rfc6979;
    void* data_ = NULL;

    secp256k1_ecdsa_recoverable_signature signature;
    memset(&signature, 0, sizeof(signature));
    if (!secp256k1_ecdsa_sign_recoverable(ctx, &signature, message_hash,  private_key, noncefn, data_)) {
        secp256k1_context_destroy(ctx);
        return CORE_ERR_SIGN_FAILED;
    }

    if (!secp256k1_ecdsa_recoverable_signature_serialize_compact(ctx, output, rec_id, &signature)){
        secp256k1_context_destroy(ctx);
        return CORE_ERR_SERIALIZE_FAILED;
    }

    secp256k1_context_destroy(ctx);
    return CORE_SUCCESS;
}
