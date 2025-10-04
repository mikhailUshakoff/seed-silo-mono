import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/models/token.dart';

import 'network_service.dart';
import 'wallet_service.dart';

class TokenService {
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

  List<Token>? _cachedTokens;

  /// Get tokens for the current wallet's network
  Future<List<Token>> getTokens() async {
    if (_cachedTokens != null) return _cachedTokens!;

    // Get current network from provider context if available
    // For now, fallback to direct service call
    final network = await NetworkService().getCurrentNetwork();
    final networkId = network?.id;
    if (networkId == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_tokensKeyPrefix$networkId');

    List<Token> tokens;
    if (jsonString == null) {
      // Default native token
      tokens = [
        Token(
          address: WalletService.ethAddress,
          symbol: 'ETH',
          decimals: 18,
        ),
      ];
      _cachedTokens = tokens;
      await _saveTokens();
    } else {
      final List<dynamic> jsonList = json.decode(jsonString);
      tokens = jsonList.map((e) => Token.fromJson(e)).toList();
      _cachedTokens = tokens;
    }

    return tokens;
  }

  /// Add a token to the current network
  Future<bool> addToken(String address) async {
    final tokens = await getTokens();

    // Check if already exists
    if (tokens.any((t) => t.address.toLowerCase() == address.toLowerCase())) {
      return false;
    }

    // Fetch token info from blockchain
    final tokenInfo = await WalletService().fetchTokenInfo(address);
    if (tokenInfo == null) return false;

    tokens.add(tokenInfo);
    _cachedTokens = tokens;
    await _saveTokens();
    return true;
  }

  /// Remove a token from the current network
  Future<void> removeToken(String address) async {
    final tokens = await getTokens();
    tokens.removeWhere((t) => t.address.toLowerCase() == address.toLowerCase());
    _cachedTokens = tokens;
    await _saveTokens();
  }

  /// Save tokens for current network
  Future<void> _saveTokens() async {
    final network = await(NetworkService().getCurrentNetwork());
    final networkId = network?.id;
    if (networkId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final tokens = _cachedTokens ?? [];
    final jsonList = tokens.map((t) => t.toJson()).toList();
    await prefs.setString('$_tokensKeyPrefix$networkId', json.encode(jsonList));
  }

  /// Remove tokens for a specific network (called when network is deleted)
  static Future<void> removeTokensForNetwork(String networkId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_tokensKeyPrefix$networkId');
  }

  /// Clear cache (useful when switching networks)
  void clearCache() {
    _cachedTokens = null;
  }
}