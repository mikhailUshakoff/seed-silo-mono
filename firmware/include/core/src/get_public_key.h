#include "secp256k1_c.h"
#include "../constants.h"

// get uncompressed public key
int get_public_key(uint8_t *private_key, uint8_t *output) {
    // Validate input parameters
    if (!private_key || !output) {
        return CORE_ERR_INVALID_PARAMS;
    }

    secp256k1_context *ctx;
    ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);

    secp256k1_pubkey pubkey;
    if (!secp256k1_ec_pubkey_create(ctx, &pubkey, private_key)) {
        secp256k1_context_destroy(ctx);
        return CORE_ERR_PUBKEY_CREATE;
    }

    size_t len = 65;
    if (!secp256k1_ec_pubkey_serialize(ctx, output, &len, &pubkey, SECP256K1_EC_UNCOMPRESSED)) {
        secp256k1_context_destroy(ctx);
        return CORE_ERR_PUBKEY_SERIALIZE;
    }

    secp256k1_context_destroy(ctx);
    return CORE_SUCCESS;
}
