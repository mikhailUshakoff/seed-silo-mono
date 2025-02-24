use aes::Aes256;
use block_modes::{BlockMode, Cbc};
use block_modes::block_padding::Pkcs7;
use tiny_keccak::{Hasher, Keccak};
use rand::Rng;
use dotenv::dotenv;
use std::env;
use hex;

fn main() {
    // Load environment variables from .env file
    dotenv().ok();

    // Get the encryption key from the environment
    let encryption_key = env::var("ENCRYPTION_KEY").expect("ENCRYPTION_KEY must be set");
    // Data to encrypt
    let private_key = env::var("PRIVATE_KEY").expect("PRIVATE_KEY must be set");
    let plaintext = hex::decode(private_key).unwrap();

    // Hash the encryption key using Keccak-256 to derive a 32-byte key
    let mut hasher = Keccak::v256(); // Initialize Keccak-256 hasher
    let mut hash_result = [0u8; 32]; // Keccak-256 produces a 32-byte hash
    hasher.update(encryption_key.as_bytes()); // Update with the key bytes
    hasher.finalize(&mut hash_result); // Finalize and store the result
    let key: [u8; 32] = hash_result; // Convert to 32-byte array
    let key_formatted: Vec<String> = key.iter().map(|byte| format!("0x{:02x}", byte)).collect();
    println!("key_formatted: [{}]",key_formatted.join(", "));

    // Generate a random IV (16 bytes for AES-256-CBC)
    let iv: [u8; 16] = rand::thread_rng().gen();

    // Encrypt the data
    let cipher = Cbc::<Aes256, Pkcs7>::new_from_slices(&key, &iv).unwrap();
    let ciphertext = cipher.encrypt_vec(&plaintext);

    // Print the results
    let iv_formatted: Vec<String> = iv.iter().map(|byte| format!("0x{:02x}", byte)).collect();
    println!("IV: [{}]", iv_formatted.join(", "));
    let chipertext_formatted: Vec<String> = ciphertext.iter().map(|byte| format!("0x{:02x}", byte)).collect();
    println!("Ciphertext: [{}]", chipertext_formatted.join(", "));

}