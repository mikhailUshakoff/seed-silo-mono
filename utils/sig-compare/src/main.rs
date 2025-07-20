use ethers::core::k256::ecdsa::SigningKey;
use ethers::prelude::*;
use ethers::types::{transaction::eip2718::TypedTransaction, Transaction, TxHash, Signature};
use std::str::FromStr;
use sha3::{Digest, Keccak256};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // --- Private Key ---
    let private_key = std::env::var("PRIVATE_KEY").expect("PRIVATE_KEY must be set");
    let plaintext = hex::decode(private_key).unwrap();

    // --- Config ---
    let tx_hash = std::env::var("TX_HASH").expect("TX_HASH must be set");
    println!("TX_HASH: {}", tx_hash);
    let tx_hash = TxHash::from_str(&tx_hash)?;
    let provider = Provider::<Http>::try_from("https://ethereum-holesky-rpc.publicnode.com")?;

    // --- Fetch Transaction ---
    let tx: Transaction = provider.get_transaction(tx_hash).await?
        .ok_or_else(|| anyhow::anyhow!("Transaction not found"))?;

    if tx.transaction_type != Some(U64::from(2)) {
        return Err(anyhow::anyhow!("Transaction is not EIP-1559 (type 0x2)"));
    }

    // --- Rebuild TypedTransaction ---
    let tx_req = TypedTransaction::Eip1559(Eip1559TransactionRequest {
        from: Some(tx.from),
        to: Some(NameOrAddress::Address(tx.to.unwrap())),
        value: Some(tx.value),
        data: Some(tx.input.clone()),
        nonce: Some(tx.nonce),
        chain_id: Some(tx.chain_id.unwrap_or_else(|| U256::from(1)).as_u64().into()),
        max_fee_per_gas: tx.max_fee_per_gas,
        max_priority_fee_per_gas: tx.max_priority_fee_per_gas,
        gas: Some(tx.gas),
        access_list: tx.access_list.unwrap_or_default(),
    });

    // --- Sign locally ---
    let signing_key = SigningKey::from_slice(&plaintext).unwrap();
    let rlp_unsigned = tx_req.rlp();
    let message_hash = Keccak256::digest(rlp_unsigned);

    let local_signature = signing_key.sign_prehash_recoverable(&message_hash).unwrap();
    println!("Local Signature: {}, v: {:?}", &local_signature.0, &local_signature.1);

    // --- Compare signatures ---
    let (r, s, v) = (tx.r, tx.s, tx.v) ;
    let network_sig = Signature { r, s, v: v.as_u64() };
    println!("Network Signature: {}", network_sig);

    if network_sig.r == U256::from_big_endian(&local_signature.0.r().to_bytes())
        && network_sig.s == U256::from_big_endian(&local_signature.0.s().to_bytes())
        && network_sig.v == local_signature.1.to_byte() as u64
    {
        println!("✅ Signatures match!");
    } else {
        println!("❌ Signatures differ.");
    }

    Ok(())
}
