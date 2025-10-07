use aes::Aes256;
use block_modes::{BlockMode, Cbc};
use block_modes::block_padding::Pkcs7;
use tiny_keccak::{Hasher, Keccak};
use rand::Rng;
use dotenv::dotenv;
use std::env;
use hex;

const PLAINTEXT_LEN: usize = 256;
const KEY_LEN: usize = 32;

struct KeyInfo {
    pub private_key: Vec<u8>,
    pub position: usize
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
            panic!("Invalid PRIVATE_KEYS format at index:{}",i);
        }

        let private_key_hex = parts[0].trim();
        let private_key = hex::decode(private_key_hex.trim_start_matches("0x"))
            .expect(format!("Invalid hex in private key at index:{}",i).as_str());

        if private_key.len() != KEY_LEN {
            panic!("Invalid private key length: {} at index:{}", private_key.len(),i);
        }

        let position: usize = parts[1].trim().parse().expect("Invalid position");

        if position + KEY_LEN > PLAINTEXT_LEN {
            panic!("Invalid key position: {} at index:{}", position,i);
        }

        pairs.push(KeyInfo{private_key, position});
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

    // Generate a random IV (16 bytes for AES-256-CBC)
    let iv: [u8; 16] = rand::thread_rng().gen();

    // ---- Build 128-byte plaintext buffer ----
    let mut plaintext = [0u8; PLAINTEXT_LEN];
    rand::thread_rng().fill(&mut plaintext);

    // Insert private key into the buffer
    for key_info in &private_keys {
        plaintext[key_info.position..key_info.position + KEY_LEN]
            .copy_from_slice(&key_info.private_key);
    }

    // Encrypt the data
    let cipher = Cbc::<Aes256, Pkcs7>::new_from_slices(&key, &iv).unwrap();
    let ciphertext = cipher.encrypt_vec(&plaintext);

    println!("#define DECRYPTED_DATA_LEN {}", PLAINTEXT_LEN);
    println!("#define ENCRYPTED_DATA_LEN {}", ciphertext.len());

    // Print the results
    let iv_formatted: Vec<String> = iv.iter().map(|byte| format!("0x{:02x}", byte)).collect();
    println!("#define AES_IV_INITIALIZER {{{}}}", iv_formatted.join(", "));
    let chipertext_formatted: Vec<String> = ciphertext.iter().map(|byte| format!("0x{:02x}", byte)).collect();
    println!("#define ENCRYPTED_DATA_INITIALIZER {{{}}}", chipertext_formatted.join(", "));

}
