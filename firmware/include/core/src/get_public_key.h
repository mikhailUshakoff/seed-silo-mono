#include "secp256k1_recovery.h"
#include "secp256k1_c.h"
#include "module/recovery/main_impl.h"


// get uncompressed public key
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
