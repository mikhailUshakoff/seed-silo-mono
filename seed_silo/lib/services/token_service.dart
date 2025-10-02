import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/models/network_type.dart';
import 'package:seed_silo/services/network_service.dart';
import 'package:seed_silo/services/wallets/wallet_service_factory.dart';
import 'package:seed_silo/services/wallets/ethereum_wallet_service.dart';

class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  static const String _tokensKeyPrefix = 'tokens_';

  // ERC20 ABI for Ethereum-based tokens
  static const String erc20Abi = '''
      [
        {"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"type":"function"},
        {"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"},
        {"constant":true,"inputs":[{"name":"owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"type":"function"},
        {"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"}
      ]
    ''';

  final _networkService = NetworkService();
  final Map<String, List<Token>> _tokensByNetwork = {};

  /// Get default native token for a network
  Token _getDefaultNativeToken(Network network) {
    switch (network.type) {
      case NetworkType.ethereum:
        return Token(
          symbol: 'ETH',
          address: '0x0000000000000000000000000000000000000000',
          decimals: 18,
        );
      case NetworkType.bitcoin:
        return Token(
          symbol: 'BTC',
          address: 'native',
          decimals: 8,
        );
      case NetworkType.solana:
        return Token(
          symbol: 'SOL',
          address: 'native',
          decimals: 9,
        );
      case NetworkType.cosmos:
        return Token(
          symbol: 'ATOM',
          address: 'native',
          decimals: 6,
        );
    }
  }

  /// Check if token is native for the current network
  Future<bool> isNativeToken(String tokenAddress) async {
    final network = await _networkService.getCurrentNetwork();
    if (network == null) return false;

    final walletService = WalletServiceFactory.getWalletService(network);
    return walletService.isNativeToken(tokenAddress);
  }

  /// Get tokens for the current network
  Future<List<Token>> getTokens() async {
    final network = await _networkService.getCurrentNetwork();
    if (network == null) return [];

    if (_tokensByNetwork.containsKey(network.id)) {
      return _tokensByNetwork[network.id]!;
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_tokensKeyPrefix${network.id}');

    List<Token> tokens;
    if (jsonString == null) {
      // Default native token
      tokens = [_getDefaultNativeToken(network)];
      _tokensByNetwork[network.id] = tokens;
      await _saveTokens();
    } else {
      final List<dynamic> jsonList = json.decode(jsonString);
      tokens = jsonList.map((e) => Token.fromJson(e)).toList();
      _tokensByNetwork[network.id] = tokens;
    }

    return tokens;
  }

  /// Add a token to the current network
  Future<bool> addToken(String address) async {
    final network = await _networkService.getCurrentNetwork();
    if (network == null) return false;

    final tokens = await getTokens();

    // Check if already exists
    if (tokens.any((t) => t.address.toLowerCase() == address.toLowerCase())) {
      return false;
    }

    // Fetch token info from blockchain using appropriate wallet service
    final walletService = WalletServiceFactory.getWalletService(network);
    final tokenInfo = await walletService.fetchTokenInfo(address, network.rpcUrl);

    if (tokenInfo == null) return false;

    tokens.add(tokenInfo);
    _tokensByNetwork[network.id] = tokens;
    await _saveTokens();
    return true;
  }

  /// Remove a token from the current network
  Future<void> removeToken(String address) async {
    final network = await _networkService.getCurrentNetwork();
    if (network == null) return;

    final tokens = await getTokens();
    tokens.removeWhere((t) => t.address.toLowerCase() == address.toLowerCase());
    _tokensByNetwork[network.id] = tokens;
    await _saveTokens();
  }

  /// Get token balance for a wallet
  Future<BigInt> getBalance(String walletAddress, String tokenAddress) async {
    final network = await _networkService.getCurrentNetwork();
    if (network == null) return BigInt.zero;

    final walletService = WalletServiceFactory.getWalletService(network);

    // Special handling for Ethereum to use the WithRpc method
    if (walletService is EthereumWalletService) {
      return await walletService.getBalanceWithRpc(
        walletAddress,
        tokenAddress,
        network.rpcUrl,
      );
    }

    // For other chains, use base method (when implemented)
    return await walletService.getBalance(walletAddress, tokenAddress);
  }

  /// Save tokens for current network
  Future<void> _saveTokens() async {
    final network = await _networkService.getCurrentNetwork();
    if (network == null) return;

    final prefs = await SharedPreferences.getInstance();
    final tokens = _tokensByNetwork[network.id] ?? [];
    final jsonList = tokens.map((t) => t.toJson()).toList();
    await prefs.setString('$_tokensKeyPrefix${network.id}', json.encode(jsonList));
  }

  /// Remove tokens for a specific network (called when network is deleted)
  Future<void> removeTokensForNetwork(String networkId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_tokensKeyPrefix$networkId');
    _tokensByNetwork.remove(networkId);
  }

  /// Clear cache (useful for testing or logout)
  void clearCache() {
    _tokensByNetwork.clear();
  }
}