use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use dotenv::dotenv;
use hex;
use rand::Rng;
use std::env;
use tiny_keccak::{Hasher, Keccak};

const PLAINTEXT_LEN: usize = 256;
const KEY_LEN: usize = 32;
const GCM_TAG_LEN: usize = 16;
const GCM_NONCE_LEN: usize = 12;

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
    let encryption_key = env::var("ENCRYPTION_KEY").expect("ENCRYPTION_KEY must be set");

    // Hash the encryption key using Keccak-256 to derive a 32-byte key
    let mut hasher = Keccak::v256(); // Initialize Keccak-256 hasher
    let mut hash_result = [0u8; 32]; // Keccak-256 produces a 32-byte hash
    hasher.update(encryption_key.as_bytes()); // Update with the key bytes
    hasher.finalize(&mut hash_result); // Finalize and store the result
    let key: [u8; 32] = hash_result; // Convert to 32-byte array
                                     //let key_formatted: Vec<String> = key.iter().map(|byte| format!("0x{:02x}", byte)).collect();
                                     //println!("key_formatted: [{}]",key_formatted.join(", "));

    // Generate a random nonce (12 bytes for AES-GCM)
    let nonce_bytes: [u8; GCM_NONCE_LEN] = rand::thread_rng().gen();
    let nonce = Nonce::from_slice(&nonce_bytes);

    // ---- Build 128-byte plaintext buffer ----
    let mut plaintext = [0u8; PLAINTEXT_LEN];
    rand::thread_rng().fill(&mut plaintext);

    // Insert private key into the buffer
    for key_info in &private_keys {
        plaintext[key_info.position..key_info.position + KEY_LEN]
            .copy_from_slice(&key_info.private_key);
    }

    // Encrypt the data using AES-GCM
    let cipher = Aes256Gcm::new_from_slice(&key).unwrap();
    let ciphertext = cipher
        .encrypt(nonce, plaintext.as_ref())
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
    let nonce_formatted: Vec<String> = nonce_bytes
        .iter()
        .map(|byte| format!("0x{:02x}", byte))
        .collect();
    println!(
        "#define GCM_IV_INITIALIZER {{{}}}",
        nonce_formatted.join(", ")
    );
    let encrypted_formatted: Vec<String> = encrypted_data
        .iter()
        .map(|byte| format!("0x{:02x}", byte))
        .collect();
    println!(
        "#define ENCRYPTED_DATA_INITIALIZER {{{}}}",
        encrypted_formatted.join(", ")
    );

    let tag_formatted: Vec<String> = tag.iter().map(|byte| format!("0x{:02x}", byte)).collect();
    println!(
        "#define GCM_TAG_INITIALIZER {{{}}}",
        tag_formatted.join(", ")
    );
    println!("");
    println!("#endif // INPUT_H");
}

#[cfg(test)]
mod tests {
    use super::*;

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
        let nonce = Nonce::from_slice(&nonce_bytes);

        // Create test plaintext
        let plaintext: [u8; PLAINTEXT_LEN] = [0x42; PLAINTEXT_LEN];

        // Encrypt
        let cipher = Aes256Gcm::new_from_slice(&key).unwrap();
        let ciphertext = cipher
            .encrypt(nonce, plaintext.as_ref())
            .expect("encryption failure");

        // Verify ciphertext length (plaintext + 16-byte tag)
        assert_eq!(ciphertext.len(), PLAINTEXT_LEN + GCM_TAG_LEN);

        // Decrypt
        let decrypted = cipher
            .decrypt(nonce, ciphertext.as_ref())
            .expect("decryption failure");

        // Verify decrypted matches original
        assert_eq!(decrypted.as_slice(), &plaintext);
    }

    #[test]
    fn test_tag_extraction() {
        let key: [u8; 32] = [0x00; 32];
        let nonce_bytes: [u8; GCM_NONCE_LEN] = [0x00; GCM_NONCE_LEN];
        let nonce = Nonce::from_slice(&nonce_bytes);
        let plaintext: [u8; PLAINTEXT_LEN] = [0x42; PLAINTEXT_LEN];

        let cipher = Aes256Gcm::new_from_slice(&key).unwrap();
        let ciphertext = cipher
            .encrypt(nonce, plaintext.as_ref())
            .expect("encryption failure");

        // Extract tag
        let tag_offset = ciphertext.len() - GCM_TAG_LEN;
        let encrypted_data = &ciphertext[..tag_offset];
        let tag = &ciphertext[tag_offset..];

        assert_eq!(encrypted_data.len(), PLAINTEXT_LEN);
        assert_eq!(tag.len(), GCM_TAG_LEN);

        // Verify decryption with full ciphertext works
        let decrypted = cipher
            .decrypt(nonce, ciphertext.as_ref())
            .expect("decryption failure");
        assert_eq!(decrypted.as_slice(), &plaintext);
    }

    #[test]
    fn test_tampered_ciphertext_fails() {
        let key: [u8; 32] = [0x00; 32];
        let nonce_bytes: [u8; GCM_NONCE_LEN] = [0x00; GCM_NONCE_LEN];
        let nonce = Nonce::from_slice(&nonce_bytes);
        let plaintext: [u8; PLAINTEXT_LEN] = [0x42; PLAINTEXT_LEN];

        let cipher = Aes256Gcm::new_from_slice(&key).unwrap();
        let mut ciphertext = cipher
            .encrypt(nonce, plaintext.as_ref())
            .expect("encryption failure");

        // Tamper with the ciphertext
        ciphertext[0] ^= 0x01;

        // Decryption should fail due to authentication tag mismatch
        let result = cipher.decrypt(nonce, ciphertext.as_ref());
        assert!(result.is_err());
    }

    #[test]
    fn test_tampered_tag_fails() {
        let key: [u8; 32] = [0x00; 32];
        let nonce_bytes: [u8; GCM_NONCE_LEN] = [0x00; GCM_NONCE_LEN];
        let nonce = Nonce::from_slice(&nonce_bytes);
        let plaintext: [u8; PLAINTEXT_LEN] = [0x42; PLAINTEXT_LEN];

        let cipher = Aes256Gcm::new_from_slice(&key).unwrap();
        let mut ciphertext = cipher
            .encrypt(nonce, plaintext.as_ref())
            .expect("encryption failure");

        // Tamper with the tag (last 16 bytes)
        let tag_offset = ciphertext.len() - 1;
        ciphertext[tag_offset] ^= 0x01;

        // Decryption should fail due to authentication tag mismatch
        let result = cipher.decrypt(nonce, ciphertext.as_ref());
        assert!(result.is_err());
    }
}
