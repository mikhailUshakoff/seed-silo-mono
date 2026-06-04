use ethers::core::k256::ecdsa::SigningKey;
use ethers::prelude::*;
use ethers::types::{Signature, Transaction, TxHash, transaction::eip2718::TypedTransaction};
use reqwest::Client;
use scraper::{Html, Selector};
use sha3::{Digest, Keccak256};
use std::str::FromStr;

async fn parse_tx_hashes(address: Address) -> anyhow::Result<Vec<TxHash>> {
    let tx_hashes = std::env::var("TX_HASHES");
    match tx_hashes {
        Ok(hashes) => {
            let hash_list: Vec<TxHash> = hashes
                .split(',')
                .map(|s| s.trim())
                .filter_map(|s| TxHash::from_str(s).ok())
                .collect();
            Ok(hash_list)
        }
        Err(_) => {
            println!("Fetching transaction hashes from the block explorer");
            let etherscan_url = std::env::var("ETHERSCAN_URL")
                .unwrap_or_else(|_| "https://hoodi.etherscan.io".to_string());
            let url = format!("{}/txs?a={:?}&f=2", etherscan_url, address);
            println!("Fetching transaction hashes from: {}", url);
            let tx_count = std::env::var("TX_COUNT")
                .ok()
                .and_then(|s| s.parse::<usize>().ok())
                .unwrap_or(10);
            println!("Fetching up to {} transactions... ", tx_count);

            let client = Client::builder()
                .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
                .build()?;

            let html = client
                .get(url)
                .header(
                    "Accept",
                    "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                )
                .header("Accept-Language", "en-US,en;q=0.5")
                .header("Referer", etherscan_url.as_str())
                .send()
                .await?
                .text()
                .await?;

            let document = Html::parse_document(&html);

            // select all tx hash links
            let selector = Selector::parse("a[href^='/tx/']").unwrap();

            let hashes: Vec<H256> = document
                .select(&selector)
                .filter_map(|el| el.value().attr("href").and_then(|h| h.strip_prefix("/tx/")))
                .filter(|h| h.starts_with("0x"))
                .filter_map(|h| H256::from_str(h).ok())
                .take(tx_count)
                .collect();
            Ok(hashes)
        }
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // --- Private Key ---
    let private_key = std::env::var("PRIVATE_KEY").expect("PRIVATE_KEY must be set");
    let plaintext = hex::decode(private_key.trim_start_matches("0x")).unwrap();

    // --- RPC URL ---
    let rpc_url =
        std::env::var("RPC_URL").unwrap_or_else(|_| "https://ethereum-hoodi-rpc.publicnode.com".to_string());
    let provider = Provider::<Http>::try_from(rpc_url.as_str())?;
    let signing_key = SigningKey::from_slice(&plaintext).unwrap();
    let wallet = LocalWallet::from(signing_key.clone());

    // --- Hash list ---
    let hash_list = parse_tx_hashes(wallet.address()).await?;
    println!("Using RPC URL: {}", rpc_url);
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
