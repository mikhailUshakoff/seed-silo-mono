use alloy::primitives::{Address, TxHash};
use alloy::providers::{Provider, ProviderBuilder};
use alloy::signers::SignerSync;
use alloy::signers::local::PrivateKeySigner;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::str::FromStr;

#[derive(Debug, Deserialize)]
struct Tx {
    hash: TxHash,
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
            .map(TxHash::from_str)
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
    let provider = ProviderBuilder::new().connect_http(rpc_url.parse()?);
    let wallet = PrivateKeySigner::from_slice(&plaintext)?;
    let chain_id = provider.get_chain_id().await?;

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
        let tx = match provider.get_transaction_by_hash(tx_hash).await {
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

        let Some(signed) = tx.inner.inner().as_eip1559() else {
            println!("❌ Transaction is not EIP-1559 (type 0x2)");
            continue;
        };

        // --- Sign locally ---
        let message_hash = signed.signature_hash();
        let local_signature = wallet.sign_hash_sync(&message_hash)?;
        println!("Local Signature: {}", local_signature);

        // --- Compare signatures ---
        let network_sig = signed.signature();
        println!("Network Signature: {}", network_sig);

        if network_sig == &local_signature {
            println!("✅ Signatures match!");
        } else {
            println!("❌ Signatures differ.");
        }
    }

    Ok(())
}
