use aes::Aes256;
use block_modes::{BlockMode, Cbc};
use block_modes::block_padding::Pkcs7;
use tiny_keccak::{Hasher, Keccak};
use rand::Rng;
use dotenv::dotenv;
use std::env;
use hex;
use secp256k1::{SecretKey, PublicKey, Secp256k1};

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
    //println!("{:02x?}",encryption_key.as_bytes());
    //let encryption_key: Vec<u8> =  vec!{0x6d, 0x79, 0x70, 0x61, 0x73};
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
/*
    let private_key_bytes = plaintext;
    let secp = Secp256k1::new();
    // Parse the private key
    let secret_key = SecretKey::from_slice(&private_key_bytes).expect("Invalid private key");

    // Derive the public key
    let public_key = PublicKey::from_secret_key(&secp, &secret_key);

    // Serialize the public key to compressed or uncompressed format
    let compressed_public_key = public_key.serialize(); // Compressed (33 bytes)
    let uncompressed_public_key = public_key.serialize_uncompressed(); // Uncompressed (65 bytes)

    // Convert the public key to hex
    let compressed_public_key_hex = hex::encode(compressed_public_key);
    let uncompressed_public_key_hex = hex::encode(&uncompressed_public_key[1..]); // Exclude the leading '0x04'

    println!("Compressed Public Key: {}", compressed_public_key_hex);
    println!("Uncompressed Public Key: {}", uncompressed_public_key_hex);
*/

}