use ethers::core::k256::ecdsa::SigningKey;
use ethers::prelude::*;
use ethers::types::{Signature, Transaction, TxHash, transaction::eip2718::TypedTransaction};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use sha3::{Digest, Keccak256};
use std::str::FromStr;

#[derive(Debug, Deserialize)]
struct Tx {
    hash: H256,
}

#[derive(Debug, Deserialize)]
struct Response {
    // status: String,
    // message: String,
    result: Vec<Tx>,
}

#[derive(Serialize)]
struct EtherscanQuery {
    chainid: u64,
    apikey: String,
    address: String,
    sort: &'static str,
    module: &'static str,
    action: &'static str,
    page: u32,
    offset: usize,
}

async fn parse_tx_hashes(chain_id: u64, address: Address) -> anyhow::Result<Vec<TxHash>> {
    if let Ok(hashes) = std::env::var("TX_HASHES") {
        return Ok(hashes
            .split(',')
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(H256::from_str)
            .collect::<std::result::Result<_, _>>()?);
    }

    let api_key = std::env::var("API_KEY").expect("API_KEY must be set (or provide TX_HASHES)");

    let tx_count = std::env::var("TX_COUNT")
        .ok()
        .and_then(|v| v.parse::<usize>().ok())
        .unwrap_or(10);

    let client = Client::new();

    let query = EtherscanQuery {
        chainid: chain_id,
        apikey: api_key,
        address: format!("{address:#x}"),
        sort: "desc",
        module: "account",
        action: "txlist",
        page: 1,
        offset: tx_count,
    };

    let response: Response = client
        .get("https://api.etherscan.io/v2/api")
        .query(&query)
        .send()
        .await
        .expect("failed to send request to etherscan")
        .error_for_status()
        .expect("etherscan returned error status")
        .json()
        .await
        .expect("failed to decode etherscan response");

    if response.result.is_empty() {
        return Ok(vec![]);
    }

    Ok(response.result.into_iter().map(|tx| tx.hash).collect())
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // --- Private Key ---
    let private_key = std::env::var("PRIVATE_KEY").expect("PRIVATE_KEY must be set");
    let plaintext = hex::decode(private_key.trim_start_matches("0x")).unwrap();

    // --- RPC URL ---
    let rpc_url = std::env::var("RPC_URL")
        .unwrap_or_else(|_| "https://ethereum-hoodi-rpc.publicnode.com".to_string());
    let provider = Provider::<Http>::try_from(rpc_url.as_str())?;
    let signing_key = SigningKey::from_slice(&plaintext).unwrap();
    let wallet = LocalWallet::from(signing_key.clone());
    let chain_id = provider.get_chainid().await?.as_u64();

    // --- Hash list ---
    let hash_list = parse_tx_hashes(chain_id, wallet.address()).await?;
    println!("Using RPC URL: {}", rpc_url);
    println!("Chain ID: {}", chain_id);
    println!("Wallet Address: {:?}", wallet.address());

    let hash_len = hash_list.len();
    for (index, tx_hash) in hash_list.into_iter().enumerate() {
        println!("\n--- Processing hash {} of {} ---", index + 1, hash_len);
        println!("TX_HASH: {}", tx_hash);

        // --- Fetch Transaction ---
        let tx: Transaction = match provider.get_transaction(tx_hash).await {
            Ok(Some(tx)) => tx,
            Ok(None) => {
                println!("❌ Transaction not found");
                continue;
            }
            Err(e) => {
                println!("❌ Error fetching transaction: {}", e);
                continue;
            }
        };

        if tx.transaction_type != Some(U64::from(2)) {
            println!("❌ Transaction is not EIP-1559 (type 0x2)");
            continue;
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
        let rlp_unsigned = tx_req.rlp();
        let message_hash = Keccak256::digest(rlp_unsigned);

        let local_signature = signing_key.sign_prehash_recoverable(&message_hash).unwrap();
        println!(
            "Local Signature: {}, v: {:?}",
            &local_signature.0, &local_signature.1
        );

        // --- Compare signatures ---
        let (r, s, v) = (tx.r, tx.s, tx.v);
        let network_sig = Signature {
            r,
            s,
            v: v.as_u64(),
        };
        println!("Network Signature: {}", network_sig);

        if network_sig.r == U256::from_big_endian(&local_signature.0.r().to_bytes())
            && network_sig.s == U256::from_big_endian(&local_signature.0.s().to_bytes())
            && network_sig.v == local_signature.1.to_byte() as u64
        {
            println!("✅ Signatures match!");
        } else {
            println!("❌ Signatures differ.");
        }
    }

    Ok(())
}
