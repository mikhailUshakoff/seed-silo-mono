import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/models/token.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

class EthWalletService {
  static final EthWalletService _instance = EthWalletService._internal();
  factory EthWalletService() => _instance;
  EthWalletService._internal();

  static const String _tokensKey = 'tokens';

  List<Token> _tokens = [];

  Future<List<Token>> getTokens() async {
    if (_tokens.isNotEmpty) return _tokens;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_tokensKey);

    if (jsonString == null) {
      // Default token ETH
      _tokens = [
        Token(
            symbol: 'ETH',
            address: '0x0000000000000000000000000000000000000000',
            decimals: 18),
      ];
      await _saveTokens();
    } else {
      final List<dynamic> jsonList = json.decode(jsonString);
      _tokens = jsonList.map((e) => Token.fromJson(e)).toList();
    }

    return _tokens;
  }

  Future<void> addToken(String address) async {
    // Check if already added
    if (_tokens.any((t) => t.address.toLowerCase() == address.toLowerCase())) return;

    // Fetch token info (symbol, decimals) from blockchain
    final tokenInfo = await _fetchTokenInfo(address);
    if (tokenInfo == null) return; // handle failure silently

    _tokens.add(tokenInfo);
    await _saveTokens();
  }

  Future<void> removeToken(String address) async {
    _tokens
        .removeWhere((t) => t.address.toLowerCase() == address.toLowerCase());
    await _saveTokens();
  }

  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _tokens.map((t) => t.toJson()).toList();
    await prefs.setString(_tokensKey, json.encode(jsonList));
  }

  Future<Token?> _fetchTokenInfo(String address) async {
    try {
      final Web3Client client =
          Web3Client('https://ethereum-holesky-rpc.publicnode.com', Client());

      final EthereumAddress tokenAddress = EthereumAddress.fromHex(address);

      const String abi = '''
      [
        {"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"type":"function"},
        {"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"}
      ]
    ''';

      final DeployedContract contract = DeployedContract(
        ContractAbi.fromJson(abi, 'ERC20'),
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
