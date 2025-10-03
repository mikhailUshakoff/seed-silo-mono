import 'dart:typed_data';
import 'package:seed_silo/models/token.dart';

/// Abstract base class for all blockchain wallet implementations
abstract class BaseWalletService {
  /// Get the RPC URL (set by network context)
  String? get rpcUrl;
  set rpcUrl(String? url);

  /// Get the network ID (set by network context)
  String? get networkId;
  set networkId(String? id);

  /// Get wallet address from password
  Future<String?> getAddress(Uint8List textPassword);

  /// Get address from public key
  String getAddressFromPublicKey(Uint8List publicKey);

  /// Get tokens for this wallet's network
  Future<List<Token>> getTokens();

  /// Add a token to this wallet's network
  Future<bool> addToken(String address);

  /// Remove a token from this wallet's network
  Future<void> removeToken(String address);

  /// Get token balance for a wallet
  Future<BigInt> getBalance(String walletAddress, String tokenAddress);

  /// Build a transaction
  Future<TransactionData?> buildTransaction({
    required String from,
    required String to,
    required String amount,
    required String tokenAddress,
    FeeLevel feeLevel = FeeLevel.medium,
  });

  /// Send a signed transaction
  Future<String?> sendTransaction(
    Uint8List textPassword,
    TransactionData transaction,
  );

  /// Decode transaction data for display
  String? decodeTransactionData(Uint8List? data, int decimals);

  /// Convert BigInt to decimal string with formatting
  String convert2Decimal(BigInt value, int decimals);

  /// Fetch token information from blockchain
  Future<Token?> fetchTokenInfo(String address);

  /// Check if token is native (e.g., ETH, BTC, SOL)
  bool isNativeToken(String tokenAddress);

  /// Get default native token for this blockchain
  Token getDefaultNativeToken();

  /// Clear token cache (called when switching networks)
  void clearTokenCache();
}

/// Transaction data structure that all implementations should use
class TransactionData {
  final dynamic rawTransaction;
  final int chainId;
  final String? displayData;

  TransactionData({
    required this.rawTransaction,
    required this.chainId,
    this.displayData,
  });
}

/// Fee level for transaction priority
enum FeeLevel {
  low,
  medium,
  high,
}