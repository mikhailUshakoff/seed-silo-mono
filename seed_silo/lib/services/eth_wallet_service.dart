import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:seed_silo/services/hardware_wallet_service.dart';
import 'package:seed_silo/utils/nullify.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/models/token.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

class EthWalletService {
  static final EthWalletService _instance = EthWalletService._internal();
  factory EthWalletService() => _instance;
  EthWalletService._internal();

  static const String _tokensKey = 'tokens';

  static const String rpcUrl = 'https://ethereum-holesky-rpc.publicnode.com';
  static const String _ethAddress =
      '0x0000000000000000000000000000000000000000';
  static const String erc20Abi = '''
      [
        {"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"type":"function"},
        {"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"},
        {"constant":true,"inputs":[{"name":"owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"type":"function"},
        {"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"}
      ]
    ''';

  List<Token> _tokens = [];
  Uint8List? _publicKey;
  String? _walletAddress;

  // get wallet address
  String get walletAddress {
    if (_walletAddress == null) {
      throw Exception('Wallet address has not been set');
    }
    return _walletAddress!;
  }

  String getEthereumAddressFromPublicKey(Uint8List publicKey) {
    Uint8List hashedKey = keccak256(publicKey);
    Uint8List addressBytes = Uint8List.fromList(hashedKey.sublist(12));
    return '0x${hex.encode(addressBytes)}';
  }

  String? decodeTransactionData(Uint8List? data) {
    if (data == null || data.isEmpty) return null;

    final contract = DeployedContract(
      ContractAbi.fromJson(erc20Abi, 'ERC20'),
      EthereumAddress.fromHex('0x0'), // dummy address, not used for decoding
    );

    final paramData = data.sublist(4); // skip selector
    final decoded = TupleType([
      AddressType(),
      UintType(length: 256),
    ]).decode(paramData.buffer, 0);

    final to = decoded.data[0] as EthereumAddress;
    final value = decoded.data[1] as BigInt;

    return 'Function: transfer\nTo: ${to.hex}\nAmount (wei): $value';
  }

  Future<String?> updateAddress(Uint8List textPassword) async {
    final password = keccak256(textPassword);
    nullify(textPassword);
    _publicKey =
        await HardwareWalletService().getUncompressedPublicKey(password);
    if (_publicKey == null) {
      _walletAddress = null;
    } else {
      _walletAddress = getEthereumAddressFromPublicKey(_publicKey!);
    }
    return _walletAddress;
  }

  Future<BigInt> getBalance(String token) async {
    if (_walletAddress == null) return BigInt.from(0);
    final httpClient = http.Client();
    final Web3Client ethClient = Web3Client(rpcUrl, httpClient);
    final walletAddress = EthereumAddress.fromHex(_walletAddress!);
    if (token == _ethAddress) {
      final balance = await ethClient.getBalance(walletAddress);
      return balance.getInWei;
    } else {
      //ERC20 get balance
      final EthereumAddress tokenAddress = EthereumAddress.fromHex(token);

      final contract = DeployedContract(
        ContractAbi.fromJson(erc20Abi, 'ERC20'),
        tokenAddress,
      );

      final balanceFunction = contract.function('balanceOf');

      final balance = await ethClient.call(
        contract: contract,
        function: balanceFunction,
        params: [walletAddress],
      );

      // TODO remove
      await Future.delayed(const Duration(seconds: 5));

      return balance.first as BigInt;
    }
  }

  Future<(BigInt, Transaction)> buildTransaction(
    String from,
    String token,
    String dst,
    String amount,
  ) async {
    final httpClient = http.Client();
    final Web3Client ethClient = Web3Client(rpcUrl, httpClient);

    final sender = EthereumAddress.fromHex(from);
    print('sender: $sender');
    final dstAddress = EthereumAddress.fromHex(dst);
    final isEth = token.toLowerCase() == _ethAddress.toLowerCase();
    final nonce = await ethClient.getTransactionCount(sender);
    final chainId = await ethClient.getChainId();

    final maxPriorityFeePerGas = EtherAmount.inWei(BigInt.from(1e9)); // 1 Gwei
    final baseFeePerGas = await ethClient.getGasPrice();
    final maxFeePerGas = EtherAmount.inWei(
      baseFeePerGas.getInWei * BigInt.from(2) + BigInt.from(1e9),
    );

    if (isEth) {
      final value = EtherAmount.fromBase10String(EtherUnit.wei, amount);

      return (
        chainId,
        Transaction(
          to: dstAddress,
          value: value,
          maxGas: 21000,
          nonce: nonce,
          maxFeePerGas: maxFeePerGas,
          maxPriorityFeePerGas: maxPriorityFeePerGas,
        )
      );
    } else {
      // Build ERC-20 token transfer
      final tokenAddress = EthereumAddress.fromHex(token);

      final contract = DeployedContract(
        ContractAbi.fromJson(erc20Abi, 'ERC20'),
        tokenAddress,
      );

      final transferFunction = contract.function('transfer');

      final amountInt = BigInt.parse(amount); // Already in wei
      final data = transferFunction.encodeCall([dstAddress, amountInt]);

      final gasLimit = await ethClient.estimateGas(
        sender: sender,
        to: tokenAddress,
        value: EtherAmount.zero(),
        data: data,
      );

      final adjustedGas = (gasLimit.toDouble() * 1.2).ceil();

      return (
        chainId,
        Transaction(
          to: tokenAddress,
          value: EtherAmount.zero(),
          data: data,
          maxGas: adjustedGas,
          nonce: nonce,
          maxFeePerGas: maxFeePerGas,
          maxPriorityFeePerGas: maxPriorityFeePerGas,
        )
      );
    }
  }

  Future<List<Token>> getTokens() async {
    if (_tokens.isNotEmpty) return _tokens;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_tokensKey);

    if (jsonString == null) {
      // Default token ETH
      _tokens = [
        Token(symbol: 'ETH', address: _ethAddress, decimals: 18),
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
    if (_tokens.any((t) => t.address.toLowerCase() == address.toLowerCase())) {
      return;
    }

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
