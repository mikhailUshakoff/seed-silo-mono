import 'dart:convert';
import 'package:seed_silo/models/network.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/models/token.dart';

import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

class TokenService {
  static const String _tokensKeyPrefix = 'tokens_';

  /// Get tokens for the current wallet's network
  Future<List<Token>> getTokens(int networkId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_tokensKeyPrefix$networkId');

    List<Token> tokens;
    if (jsonString == null) {
      // Default native token
      tokens = [
        defaultNativeToken,
      ];
      await _saveTokens(networkId, tokens);
    } else {
      final List<dynamic> jsonList = json.decode(jsonString);
      tokens = jsonList.map((e) => Token.fromJson(e)).toList();
    }

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
    await _saveTokens(network.chainId, tokens);
    return true;
  }

  /// Remove a token from the current network
  Future<void> removeToken(int networkId, String address) async {
    final tokens = await getTokens(networkId);
    tokens.removeWhere((t) => t.address.toLowerCase() == address.toLowerCase());
    await _saveTokens(networkId, tokens);
  }

  /// Save tokens for current network
  Future<void> _saveTokens(int networkId, List<Token> tokens) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = tokens.map((t) => t.toJson()).toList();
    await prefs.setString('$_tokensKeyPrefix$networkId', json.encode(jsonList));
  }

  /// Remove tokens for a specific network (called when network is deleted)
  static Future<void> removeTokensForNetwork(int networkId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_tokensKeyPrefix$networkId');
  }

  /// Clear cache (useful when switching networks) - kept for compatibility
  void clearCache() {
    // No-op since we removed caching from service
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
