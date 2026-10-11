#![allow(clippy::println_empty_string)]

use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use argon2::{Algorithm, Argon2, Params, Version};
use dotenvy::dotenv;
use rand::Rng;
use std::env;
use zeroize::Zeroizing;

const PLAINTEXT_LEN: usize = 256;
const KEY_LEN: usize = 32;
const GCM_TAG_LEN: usize = 16;
const GCM_NONCE_LEN: usize = 12;

// KDF identifier stored on the device; must match KDF_ARGON2ID in
// firmware/include/core/constants.h and the app's hardware_wallet_service.dart.
const KDF_ARGON2ID: u8 = 0x01;
const KDF_SALT_LEN: usize = 32;

// Default Argon2id cost parameters (overridable via ARGON2_M_KIB / ARGON2_T /
// ARGON2_P). The app derives the key with these on every unlock, so pick them
// for the slowest host that runs it.
const DEFAULT_M_COST_KIB: u32 = 64 * 1024;
const DEFAULT_T_COST: u32 = 3;
const DEFAULT_P_COST: u32 = 1;

// Accepted ranges; must match the bounds the app enforces before deriving.
const MIN_M_COST_KIB: u32 = 19 * 1024;
const MAX_M_COST_KIB: u32 = 1024 * 1024;
const MIN_T_COST: u32 = 1;
const MAX_T_COST: u32 = 16;
const MIN_P_COST: u32 = 1;
const MAX_P_COST: u32 = 16;

struct KdfParams {
    m_cost_kib: u32,
    t_cost: u32,
    p_cost: u32,
}

fn env_u32(name: &str, default: u32, min: u32, max: u32) -> u32 {
    let value = match env::var(name) {
        Ok(s) => s
            .trim()
            .parse()
            .unwrap_or_else(|_| panic!("{} must be an unsigned integer", name)),
        Err(_) => default,
    };
    if !(min..=max).contains(&value) {
        panic!("{} = {} is out of range [{}, {}]", name, value, min, max);
    }
    value
}

fn load_kdf_params() -> KdfParams {
    KdfParams {
        m_cost_kib: env_u32(
            "ARGON2_M_KIB",
            DEFAULT_M_COST_KIB,
            MIN_M_COST_KIB,
            MAX_M_COST_KIB,
        ),
        t_cost: env_u32("ARGON2_T", DEFAULT_T_COST, MIN_T_COST, MAX_T_COST),
        p_cost: env_u32("ARGON2_P", DEFAULT_P_COST, MIN_P_COST, MAX_P_COST),
    }
}

/// Argon2id(password, salt) -> 32-byte AES-256 key.
fn derive_key(
    password: &[u8],
    salt: &[u8; KDF_SALT_LEN],
    params: &KdfParams,
) -> Zeroizing<[u8; KEY_LEN]> {
    let argon2_params = Params::new(
        params.m_cost_kib,
        params.t_cost,
        params.p_cost,
        Some(KEY_LEN),
    )
    .expect("invalid Argon2 parameters");
    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, argon2_params);
    let mut key = Zeroizing::new([0u8; KEY_LEN]);
    argon2
        .hash_password_into(password, salt, key.as_mut())
        .expect("Argon2 hashing failed");
    key
}

fn format_bytes(bytes: &[u8]) -> String {
    bytes
        .iter()
        .map(|byte| format!("0x{:02x}", byte))
        .collect::<Vec<_>>()
        .join(", ")
}

struct KeyInfo {
    pub private_key: Vec<u8>,
    pub position: usize,
}

fn load_keys() -> Vec<KeyInfo> {
    let pairs_str = env::var("PRIVATE_KEYS").expect("PRIVATE_KEYS must be set");
    let mut pairs = Vec::new();

    for (i, pair_str) in pairs_str.split(';').enumerate() {
        if pair_str.trim().is_empty() {
            continue;
        }
        let parts: Vec<&str> = pair_str.split(',').collect();
        if parts.len() != 2 {
            panic!("Invalid PRIVATE_KEYS format at index: {}", i);
        }

        let private_key_hex = parts[0].trim();
        let private_key = hex::decode(private_key_hex.trim_start_matches("0x"))
            .unwrap_or_else(|_| panic!("Invalid hex in private key at index: {}", i));

        if private_key.len() != KEY_LEN {
            panic!(
                "Invalid private key length: {} at index: {}",
                private_key.len(),
                i
            );
        }

        let position: usize = parts[1].trim().parse().expect("Invalid position");

        if position + KEY_LEN > PLAINTEXT_LEN {
            panic!("Invalid key position: {} at index: {}", position, i);
        }

        pairs.push(KeyInfo {
            private_key,
            position,
        });
    }

    pairs
}

fn main() {
    // Load environment variables from .env file
    dotenv().ok();

    // private keys
    let private_keys = load_keys();
    // Get the encryption key from the environment
    let encryption_key =
        Zeroizing::new(env::var("ENCRYPTION_KEY").expect("ENCRYPTION_KEY must be set"));
    let kdf_params = load_kdf_params();

    // Fresh random per-device salt; not secret, stored on the device and
    // served to the app via CMD_GET_KDF_PARAMS.
    let salt: [u8; KDF_SALT_LEN] = rand::thread_rng().gen();

    // Derive the 32-byte AES key with Argon2id
    let key = derive_key(encryption_key.as_bytes(), &salt, &kdf_params);

    // Generate a random nonce (12 bytes for AES-GCM)
    let nonce_bytes: [u8; GCM_NONCE_LEN] = rand::thread_rng().gen();
    let nonce = Nonce::try_from(&nonce_bytes[..]).unwrap();

    // ---- Build 128-byte plaintext buffer ----
    let mut plaintext = Zeroizing::new([0u8; PLAINTEXT_LEN]);
    rand::thread_rng().fill(plaintext.as_mut());

    // Insert private key into the buffer
    for key_info in &private_keys {
        plaintext[key_info.position..key_info.position + KEY_LEN]
            .copy_from_slice(&key_info.private_key);
    }

    // Encrypt the data using AES-GCM
    let cipher = Aes256Gcm::new_from_slice(key.as_ref()).unwrap();
    let ciphertext = cipher
        .encrypt(&nonce, plaintext.as_ref())
        .expect("encryption failure!");

    // GCM appends a 16-byte authentication tag to the ciphertext
    let tag_offset = ciphertext.len() - GCM_TAG_LEN;
    let encrypted_data = &ciphertext[..tag_offset];
    let tag = &ciphertext[tag_offset..];

    println!("#ifndef INPUT_H");
    println!("#define INPUT_H");
    println!("");
    println!("#define DECRYPTED_DATA_LEN {}", PLAINTEXT_LEN);
    println!("#define ENCRYPTED_DATA_LEN {}", encrypted_data.len());
    println!("#define GCM_IV_LEN {}", GCM_NONCE_LEN);
    println!("#define GCM_TAG_LEN {}", GCM_TAG_LEN);
    println!("");

    // Print the results
    println!(
        "#define GCM_IV_INITIALIZER {{{}}}",
        format_bytes(&nonce_bytes)
    );
    println!(
        "#define ENCRYPTED_DATA_INITIALIZER {{{}}}",
        format_bytes(encrypted_data)
    );
    println!("#define GCM_TAG_INITIALIZER {{{}}}", format_bytes(tag));
    println!("");

    // Argon2id parameters the app needs to re-derive the AES key
    println!("#define KDF_ALGORITHM 0x{:02x}", KDF_ARGON2ID);
    println!("#define KDF_SALT_LEN {}", KDF_SALT_LEN);
    println!("#define KDF_SALT_INITIALIZER {{{}}}", format_bytes(&salt));
    println!("#define KDF_M_COST_KIB {}", kdf_params.m_cost_kib);
    println!("#define KDF_T_COST {}", kdf_params.t_cost);
    println!("#define KDF_P_COST {}", kdf_params.p_cost);
    println!("");
    println!("#endif // INPUT_H");
}

#[cfg(test)]
mod tests {
    use super::*;

    const TEST_KDF_PARAMS: KdfParams = KdfParams {
        m_cost_kib: 1024,
        t_cost: 2,
        p_cost: 1,
    };

    fn test_salt() -> [u8; KDF_SALT_LEN] {
        core::array::from_fn(|i| i as u8)
    }

    #[test]
    fn test_derive_key_known_vector() {
        // Shared with seed_silo/test/services/kdf_service_test.dart so the
        // provisioning tool and the app are checked to derive the same key.
        let key = derive_key(b"password", &test_salt(), &TEST_KDF_PARAMS);
        assert_eq!(
            hex::encode(key.as_ref()),
            "82b64c8aa46eb41006d80da81b932b36d7b0e7b86bde93fd475a2f3b15478e02"
        );
    }

    #[test]
    fn test_derive_key_depends_on_salt() {
        let key1 = derive_key(b"password", &test_salt(), &TEST_KDF_PARAMS);
        let mut salt2 = test_salt();
        salt2[0] ^= 0x01;
        let key2 = derive_key(b"password", &salt2, &TEST_KDF_PARAMS);
        assert_ne!(key1.as_ref(), key2.as_ref());
    }

    #[test]
    fn test_default_kdf_params_are_in_range() {
        assert!((MIN_M_COST_KIB..=MAX_M_COST_KIB).contains(&DEFAULT_M_COST_KIB));
        assert!((MIN_T_COST..=MAX_T_COST).contains(&DEFAULT_T_COST));
        assert!((MIN_P_COST..=MAX_P_COST).contains(&DEFAULT_P_COST));
    }

    #[test]
    fn test_encrypt_decrypt_roundtrip() {
        // Create a test key
        let key: [u8; 32] = [
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d,
            0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b,
            0x1c, 0x1d, 0x1e, 0x1f,
        ];

        // Create a test nonce
        let nonce_bytes: [u8; GCM_NONCE_LEN] = [
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b,
        ];
        let nonce = Nonce::try_from(&nonce_bytes[..]).unwrap();

        // Create test plaintext
        let plaintext: [u8; PLAINTEXT_LEN] = [0x42; PLAINTEXT_LEN];

        // Encrypt
        let cipher = Aes256Gcm::new_from_slice(&key).unwrap();
        let ciphertext = cipher
            .encrypt(&nonce, plaintext.as_ref())
            .expect("encryption failure");

        // Verify ciphertext length (plaintext + 16-byte tag)
        assert_eq!(ciphertext.len(), PLAINTEXT_LEN + GCM_TAG_LEN);

        // Decrypt
        let decrypted = cipher
            .decrypt(&nonce, ciphertext.as_ref())
            .expect("decryption failure");

        // Verify decrypted matches original
        assert_eq!(decrypted.as_slice(), &plaintext);
    }

    #[test]
    fn test_tag_extraction() {
        let key: [u8; 32] = [0x00; 32];
        let nonce_bytes: [u8; GCM_NONCE_LEN] = [0x00; GCM_NONCE_LEN];
        let nonce = Nonce::try_from(&nonce_bytes[..]).unwrap();
        let plaintext: [u8; PLAINTEXT_LEN] = [0x42; PLAINTEXT_LEN];

        let cipher = Aes256Gcm::new_from_slice(&key).unwrap();
        let ciphertext = cipher
            .encrypt(&nonce, plaintext.as_ref())
            .expect("encryption failure");

        // Extract tag
        let tag_offset = ciphertext.len() - GCM_TAG_LEN;
        let encrypted_data = &ciphertext[..tag_offset];
        let tag = &ciphertext[tag_offset..];

        assert_eq!(encrypted_data.len(), PLAINTEXT_LEN);
        assert_eq!(tag.len(), GCM_TAG_LEN);

        // Verify decryption with full ciphertext works
        let decrypted = cipher
            .decrypt(&nonce, ciphertext.as_ref())
            .expect("decryption failure");
        assert_eq!(decrypted.as_slice(), &plaintext);
    }

    #[test]
    fn test_tampered_ciphertext_fails() {
        let key: [u8; 32] = [0x00; 32];
        let nonce_bytes: [u8; GCM_NONCE_LEN] = [0x00; GCM_NONCE_LEN];
        let nonce = Nonce::try_from(&nonce_bytes[..]).unwrap();
        let plaintext: [u8; PLAINTEXT_LEN] = [0x42; PLAINTEXT_LEN];

        let cipher = Aes256Gcm::new_from_slice(&key).unwrap();
        let mut ciphertext = cipher
            .encrypt(&nonce, plaintext.as_ref())
            .expect("encryption failure");

        // Tamper with the ciphertext
        ciphertext[0] ^= 0x01;

        // Decryption should fail due to authentication tag mismatch
        let result = cipher.decrypt(&nonce, ciphertext.as_ref());
        assert!(result.is_err());
    }

    #[test]
    fn test_tampered_tag_fails() {
        let key: [u8; 32] = [0x00; 32];
        let nonce_bytes: [u8; GCM_NONCE_LEN] = [0x00; GCM_NONCE_LEN];
        let nonce = Nonce::try_from(&nonce_bytes[..]).unwrap();
        let plaintext: [u8; PLAINTEXT_LEN] = [0x42; PLAINTEXT_LEN];

        let cipher = Aes256Gcm::new_from_slice(&key).unwrap();
        let mut ciphertext = cipher
            .encrypt(&nonce, plaintext.as_ref())
            .expect("encryption failure");

        // Tamper with the tag (last 16 bytes)
        let tag_offset = ciphertext.len() - 1;
        ciphertext[tag_offset] ^= 0x01;

        // Decryption should fail due to authentication tag mismatch
        let result = cipher.decrypt(&nonce, ciphertext.as_ref());
        assert!(result.is_err());
    }
}
