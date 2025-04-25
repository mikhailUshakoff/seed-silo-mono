use alloy_signer_local::{
    coins_bip39::{English, Mnemonic},
    MnemonicBuilder,
};

fn main() {
    let m = Mnemonic::<English>::new_with_count(&mut rand::thread_rng(), 12).unwrap();

    println!("Mnemonic: {}", m.to_phrase());

    let mnemonic = MnemonicBuilder::<English>::default()
        .phrase(m.to_phrase())
        .build()
        .expect("Failed to generate mnemonic");

    println!("Private key: {:?}", mnemonic.to_bytes());

    println!("Address: {}", mnemonic.address());
}
