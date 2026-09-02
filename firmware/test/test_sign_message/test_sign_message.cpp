#include <unity.h>
#include <cstring>
#include <core/src/sign_message.h>

static const uint8_t PRIVATE_KEY[32] = {
    0x50, 0x10, 0xc7, 0x34, 0x63, 0x0b, 0x08, 0x31, 0x43, 0xc9, 0xdd, 0x0d, 0xef, 0x34, 0x0e, 0x43,
    0xb6, 0x7d, 0x86, 0x53, 0x34, 0xe8, 0xc9, 0x85, 0x45, 0xae, 0x22, 0x9d, 0xab, 0xed, 0x3f, 0xe5
};

static const uint8_t MESSAGE_HASH[32] = {
    0xee, 0x83, 0x92, 0x9a, 0x84, 0x92, 0x86, 0x62, 0x9b, 0x7b, 0x81, 0xae, 0x94, 0x0b, 0x9f, 0xa3,
    0xfc, 0xa8, 0x2e, 0xc0, 0x44, 0x68, 0x43, 0xd1, 0xc6, 0xc2, 0x04, 0xcf, 0x2a, 0xca, 0x31, 0x22
};

static const uint8_t EXPECTED_SIGNATURE[64] = {
    0xad, 0xf3, 0xdd, 0x03, 0x5e, 0x3a, 0x66, 0x59, 0x80, 0x90, 0x91, 0xd1, 0x07, 0x19, 0xd3, 0xb3,
    0x2b, 0xce, 0xc4, 0x02, 0xdd, 0xbb, 0x3f, 0x63, 0x83, 0x4a, 0xc5, 0x80, 0x58, 0xa3, 0x61, 0x4f,
    0x0e, 0x83, 0x8d, 0xa5, 0x2a, 0x14, 0x58, 0x05, 0x11, 0x5e, 0xf3, 0x87, 0x39, 0xc6, 0x72, 0x01,
    0xea, 0x9d, 0x15, 0x7c, 0x28, 0xd1, 0x7f, 0xd6, 0x1f, 0x09, 0xbf, 0xf5, 0x7e, 0x60, 0xc9, 0xa1
};
// last byte of the 65-byte Ethereum signature was 0x1b (v=27) -> rec_id = v - 27
static const int EXPECTED_REC_ID = 0;

static const uint8_t MESSAGE_HASH_2[32] = {
    0xaa, 0x83, 0x92, 0x9a, 0x8a, 0xa2, 0x86, 0x62, 0x9b, 0x7b, 0x81, 0xae, 0x94, 0x0b, 0x9f, 0xa3,
    0xfc, 0xa8, 0x2e, 0xc0, 0x44, 0x68, 0x43, 0xd1, 0xc6, 0xc2, 0x04, 0xcf, 0x2a, 0xca, 0x31, 0x22
};

static const uint8_t EXPECTED_SIGNATURE_2[64] = {
    0xcd, 0x69, 0x00, 0x0e, 0x61, 0x19, 0x39, 0xd4, 0xc3, 0xd8, 0xb1, 0x43, 0xbf, 0xdf, 0xa0, 0x4a,
    0x87, 0x9a, 0xc5, 0xad, 0x14, 0xef, 0xce, 0xe7, 0xa7, 0x50, 0xe1, 0xf5, 0x1b, 0xae, 0x0a, 0x41,
    0x74, 0x53, 0xf0, 0x34, 0x7a, 0x59, 0xa1, 0x68, 0x9b, 0xf8, 0x7c, 0x8e, 0x18, 0xda, 0xe5, 0xbf,
    0x56, 0xc6, 0xe3, 0xec, 0x1d, 0x23, 0x5d, 0x91, 0x16, 0x5f, 0x19, 0x41, 0xb7, 0xd0, 0xbe, 0x33
};
// last byte of the 65-byte Ethereum signature was 0x1c (v=28) -> rec_id = v - 27
static const int EXPECTED_REC_ID_2 = 1;

void test_sign_known_vector() {
    uint8_t private_key[32];
    uint8_t message_hash[32];
    memcpy(private_key, PRIVATE_KEY, sizeof(private_key));
    memcpy(message_hash, MESSAGE_HASH, sizeof(message_hash));

    uint8_t signature[64] = {0};
    int rec_id = -1;

    int result = sign(private_key, message_hash, signature, &rec_id);

    TEST_ASSERT_EQUAL_INT(CORE_SUCCESS, result);
    TEST_ASSERT_EQUAL_INT(EXPECTED_REC_ID, rec_id);
    TEST_ASSERT_EQUAL_UINT8_ARRAY(EXPECTED_SIGNATURE, signature, 64);
}

void test_sign_known_vector_2() {
    uint8_t private_key[32];
    uint8_t message_hash[32];
    memcpy(private_key, PRIVATE_KEY, sizeof(private_key));
    memcpy(message_hash, MESSAGE_HASH_2, sizeof(message_hash));

    uint8_t signature[64] = {0};
    int rec_id = -1;

    int result = sign(private_key, message_hash, signature, &rec_id);

    TEST_ASSERT_EQUAL_INT(CORE_SUCCESS, result);
    TEST_ASSERT_EQUAL_INT(EXPECTED_REC_ID_2, rec_id);
    TEST_ASSERT_EQUAL_UINT8_ARRAY(EXPECTED_SIGNATURE_2, signature, 64);
}

void test_sign_rejects_null_params() {
    uint8_t private_key[32] = {0};
    uint8_t message_hash[32] = {0};
    uint8_t signature[64] = {0};
    int rec_id = -1;

    TEST_ASSERT_EQUAL_INT(CORE_ERR_INVALID_PARAMS, sign(nullptr, message_hash, signature, &rec_id));
    TEST_ASSERT_EQUAL_INT(CORE_ERR_INVALID_PARAMS, sign(private_key, nullptr, signature, &rec_id));
    TEST_ASSERT_EQUAL_INT(CORE_ERR_INVALID_PARAMS, sign(private_key, message_hash, nullptr, &rec_id));
    TEST_ASSERT_EQUAL_INT(CORE_ERR_INVALID_PARAMS, sign(private_key, message_hash, signature, nullptr));
}

void test_sign_is_deterministic() {
    uint8_t private_key_a[32], private_key_b[32];
    uint8_t message_hash_a[32], message_hash_b[32];
    memcpy(private_key_a, PRIVATE_KEY, sizeof(private_key_a));
    memcpy(private_key_b, PRIVATE_KEY, sizeof(private_key_b));
    memcpy(message_hash_a, MESSAGE_HASH, sizeof(message_hash_a));
    memcpy(message_hash_b, MESSAGE_HASH, sizeof(message_hash_b));

    uint8_t signature_a[64] = {0};
    uint8_t signature_b[64] = {0};
    int rec_id_a = -1, rec_id_b = -1;

    TEST_ASSERT_EQUAL_INT(CORE_SUCCESS, sign(private_key_a, message_hash_a, signature_a, &rec_id_a));
    TEST_ASSERT_EQUAL_INT(CORE_SUCCESS, sign(private_key_b, message_hash_b, signature_b, &rec_id_b));

    TEST_ASSERT_EQUAL_INT(rec_id_a, rec_id_b);
    TEST_ASSERT_EQUAL_UINT8_ARRAY(signature_a, signature_b, 64);
}

void test_sign_is_deterministic_2() {
    uint8_t private_key_a[32], private_key_b[32];
    uint8_t message_hash_a[32], message_hash_b[32];
    memcpy(private_key_a, PRIVATE_KEY, sizeof(private_key_a));
    memcpy(private_key_b, PRIVATE_KEY, sizeof(private_key_b));
    memcpy(message_hash_a, MESSAGE_HASH_2, sizeof(message_hash_a));
    memcpy(message_hash_b, MESSAGE_HASH_2, sizeof(message_hash_b));

    uint8_t signature_a[64] = {0};
    uint8_t signature_b[64] = {0};
    int rec_id_a = -1, rec_id_b = -1;

    TEST_ASSERT_EQUAL_INT(CORE_SUCCESS, sign(private_key_a, message_hash_a, signature_a, &rec_id_a));
    TEST_ASSERT_EQUAL_INT(CORE_SUCCESS, sign(private_key_b, message_hash_b, signature_b, &rec_id_b));

    TEST_ASSERT_EQUAL_INT(rec_id_a, rec_id_b);
    TEST_ASSERT_EQUAL_UINT8_ARRAY(signature_a, signature_b, 64);
}

int main(int argc, char **argv) {
    UNITY_BEGIN();
    RUN_TEST(test_sign_known_vector);
    RUN_TEST(test_sign_known_vector_2);
    RUN_TEST(test_sign_rejects_null_params);
    RUN_TEST(test_sign_is_deterministic);
    RUN_TEST(test_sign_is_deterministic_2);
    return UNITY_END();
}
