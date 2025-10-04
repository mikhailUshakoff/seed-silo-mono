import 'dart:convert';
import 'package:seed_silo/models/network.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/models/token.dart';

import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

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
  Future<List<Token>> getTokens(int networkId) async {
    if (_cachedTokens != null) return _cachedTokens!;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_tokensKeyPrefix$networkId');

    List<Token> tokens;
    if (jsonString == null) {
      // Default native token
      tokens = [
        defaultNativeToken,
      ];
      await _saveTokens(networkId);
    } else {
      final List<dynamic> jsonList = json.decode(jsonString);
      tokens = jsonList.map((e) => Token.fromJson(e)).toList();
    }

    _cachedTokens = tokens;
    return tokens;
  }

  /// Add a token to the current network
  Future<bool> addToken(Network network, String address) async {
    final tokens = await getTokens(network.chainId);

    // Check if already exists
    if (tokens.any((t) => t.address.toLowerCase() == address.toLowerCase())) {
      return false;
    }

    // Fetch token info from blockchain
    final tokenInfo = await fetchTokenInfo(network.rpcUrl, address);
    if (tokenInfo == null) return false;

    tokens.add(tokenInfo);
    _cachedTokens = tokens;
    await _saveTokens(network.chainId);
    return true;
  }

  /// Remove a token from the current network
  Future<void> removeToken(int networkId, String address) async {
    final tokens = await getTokens(networkId);
    tokens.removeWhere((t) => t.address.toLowerCase() == address.toLowerCase());
    _cachedTokens = tokens;
    await _saveTokens(networkId);
  }

  /// Save tokens for current network
  Future<void> _saveTokens(int networkId) async {
    final prefs = await SharedPreferences.getInstance();
    final tokens = _cachedTokens ?? [];
    final jsonList = tokens.map((t) => t.toJson()).toList();
    await prefs.setString('$_tokensKeyPrefix$networkId', json.encode(jsonList));
  }

  /// Remove tokens for a specific network (called when network is deleted)
  static Future<void> removeTokensForNetwork(int networkId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_tokensKeyPrefix$networkId');
  }

  /// Clear cache (useful when switching networks)
  void clearCache() {
    _cachedTokens = null;
  }

    Future<Token?> fetchTokenInfo(String rpcUrl, String address) async {
    try {
      final Web3Client client = Web3Client(rpcUrl, Client());

      final EthereumAddress tokenAddress = EthereumAddress.fromHex(address);

      final DeployedContract contract = DeployedContract(
        ContractAbi.fromJson(erc20Abi, 'ERC20'),
        tokenAddress,
      );

      final symbolFunction = contract.function('symbol');
      final decimalsFunction = contract.function('decimals');

      final symbolResult = await client.call(
        contract: contract,
        function: symbolFunction,
        params: [],
      );

      final decimalsResult = await client.call(
        contract: contract,
        function: decimalsFunction,
        params: [],
      );

      final String symbol = symbolResult.first as String;
      final int decimals = decimalsResult.first.toInt();

      return Token(symbol: symbol, address: address, decimals: decimals);
    } catch (e) {
      return null;
    }
  }

}