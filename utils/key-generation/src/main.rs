use alloy_signer_local::{
    coins_bip39::{English, Mnemonic},
    MnemonicBuilder,
};
use std::env;

fn main() {
    let mnemonic_phrase = match env::var("MNEMONIC") {
        Ok(phrase) => {
            println!("Using mnemonic from environment variable");
            phrase
        }
        Err(_) => {
            println!("No mnemonic found in environment, generating new one...");
            let m = Mnemonic::<English>::new_with_count(&mut rand::thread_rng(), 12).unwrap();
            let phrase = m.to_phrase();
            println!("Mnemonic: {}", phrase);
            phrase
        }
    };

    let mnemonic = MnemonicBuilder::<English>::default()
        .phrase(mnemonic_phrase)
        .build()
        .expect("Failed to generate mnemonic");

    println!("Private key: {:?}", mnemonic.to_bytes());

    println!("Address: {}", mnemonic.address());
}
