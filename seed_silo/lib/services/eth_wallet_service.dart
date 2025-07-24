import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/models/token.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

class EthWalletService {
  static final EthWalletService _instance = EthWalletService._internal();
  factory EthWalletService() => _instance;
  EthWalletService._internal();

  static const String _tokensKey = 'tokens';

  static const String rpcUrl = 'https://ethereum-holesky-rpc.publicnode.com';
  static const String _ethAddress = '0x0000000000000000000000000000000000000000';

  List<Token> _tokens = [];

  Future<void> buildTransaction(String from,String token, String dst, String amount) async {
    final httpClient = http.Client();
    final Web3Client ethClient = Web3Client(rpcUrl, httpClient);

    if (token == _ethAddress) {
      final dstAddress = EthereumAddress.fromHex(dst);
      final sender = EthereumAddress.fromHex(from);
      int nonce = await ethClient.getTransactionCount(sender);

      final chainId = await ethClient.getChainId();

      final maxPriorityFeePerGas = EtherAmount.inWei(BigInt.from(1000000000));
      EtherAmount baseFeePerGas = await ethClient.getGasPrice();
      EtherAmount maxFeePerGas = EtherAmount.inWei(baseFeePerGas.getInWei * BigInt.from(2) + BigInt.from(1000000000));

      final value = EtherAmount.fromBase10String(EtherUnit.wei, amount);
      // Create an unsigned transaction
      final transaction = Transaction(
        to: dstAddress,
        value:  value,
        maxGas: 21000, // Standard ETH transfer gas limit
        nonce: nonce,
        maxFeePerGas: maxFeePerGas, // Fetched max fee
        maxPriorityFeePerGas: maxPriorityFeePerGas, // Fetched priority fee
        data: Uint8List.fromList([]),
      );
      final rawTransaction = transaction.getUnsignedSerialized(chainId: chainId.toInt());
    }
  }

  Future<List<Token>> getTokens() async {
    if (_tokens.isNotEmpty) return _tokens;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_tokensKey);

    if (jsonString == null) {
      // Default token ETH
      _tokens = [
        Token(
            symbol: 'ETH',
            address: _ethAddress,
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
      final Web3Client client = Web3Client(rpcUrl, Client());

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
