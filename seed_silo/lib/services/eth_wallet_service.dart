import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:seed_silo/services/hardware_wallet_service.dart';
import 'package:seed_silo/utils/nullify.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/models/network.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

enum RewardPercentile { low, medium, high }

class EthWalletService {
  static final EthWalletService _instance = EthWalletService._internal();
  factory EthWalletService() => _instance;
  EthWalletService._internal();

  static const String _networksKey = 'networks';
  static const String _currentNetworkKey = 'current_network';
  static const String _tokensKeyPrefix = 'tokens_';

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

  List<Network> _networks = [];
  Network? _currentNetwork;
  final Map<String, List<Token>> _tokensByNetwork = {};

  bool isEthToken(String token) => token == _ethAddress;

  String getEthereumAddressFromPublicKey(Uint8List publicKey) {
    Uint8List hashedKey = keccak256(publicKey);
    Uint8List addressBytes = Uint8List.fromList(hashedKey.sublist(12));
    return '0x${hex.encode(addressBytes)}';
  }

  List<dynamic> _encodeEIP1559ToRlp(
    Transaction transaction,
    MsgSignature? signature,
    int chainId,
  ) {
    final list = [
      chainId,
      transaction.nonce,
      transaction.maxPriorityFeePerGas!.getInWei,
      transaction.maxFeePerGas!.getInWei,
      transaction.maxGas,
    ];

    if (transaction.to != null) {
      list.add(transaction.to!.addressBytes);
    } else {
      list.add('');
    }

    list
      ..add(transaction.value?.getInWei)
      ..add(transaction.data);

    list.add([]);

    if (signature != null) {
      list
        ..add(signature.v)
        ..add(signature.r)
        ..add(signature.s);
    }

    return list;
  }

  String? decodeTransactionData(Uint8List? data, int decimals) {
    if (data == null || data.isEmpty) return null;

    final contract = DeployedContract(
      ContractAbi.fromJson(erc20Abi, 'ERC20'),
      EthereumAddress.fromHex(_ethAddress),
    );

    final function = contract.function('transfer');
    final selector = data.sublist(0, 4);
    final functionName = !listEquals(function.selector, selector)
        ? bytesToHex(data.sublist(0, 4), include0x: true)
        : "transfer (0xa9059cbb)";

    final paramData = data.sublist(4);
    final decoded = TupleType([
      AddressType(),
      UintType(length: 256),
    ]).decode(paramData.buffer, 0);

    final to = decoded.data[0] as EthereumAddress;
    final value = decoded.data[1] as BigInt;

    final str = convert2Decimal(value, decimals);
    return '    Function: $functionName\n    To: 0x${to.hex}\n    Amount (wei): 0x${value.toRadixString(16)} ($str)';
  }

  String convert2Decimal(BigInt value, int decimals) {
    String str = value.toRadixString(10);

    String formatted;
    if (str.length <= decimals) {
      final padded = str.padLeft(decimals, '0');
      formatted = "0.$padded";
    } else {
      final insertPoint = str.length - decimals;
      formatted =
          "${str.substring(0, insertPoint)}.${str.substring(insertPoint)}";
    }

    final parts = formatted.split('.');
    final integerPart = parts[0];
    final fractionalPart = parts.length > 1 ? parts[1] : '';

    final formattedInteger = _formatWithSeparators(integerPart);
    final formattedFractional = _formatWithSeparators(fractionalPart);

    return formattedFractional.isNotEmpty
        ? '$formattedInteger.$formattedFractional'
        : formattedInteger;
  }

  String _formatWithSeparators(String number) {
    final buffer = StringBuffer();
    final length = number.length;

    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('_');
      }
      buffer.write(number[i]);
    }

    return buffer.toString();
  }

  Future<String?> sendTransaction(
      Uint8List textPassword, Transaction tx, int chainId) async {
    if (!tx.isEIP1559) {
      nullifyUint8List(textPassword);
      return null;
    }

    final password = keccak256(textPassword);
    nullifyUint8List(textPassword);

    final rawTransaction = tx.getUnsignedSerialized(chainId: chainId);
    final sig =
        await HardwareWalletService().getSignature(password, rawTransaction);
    if (sig == null) {
      return null;
    }

    final signedTransaction = _encodeEIP1559ToRlp(tx, sig, chainId);
    final signedRlp = encode(signedTransaction);
    Uint8List tx2Send = Uint8List.fromList(signedRlp);
    tx2Send = prependTransactionType(0x02, tx2Send);

    if (_currentNetwork == null) return null;
    final Web3Client client = Web3Client(_currentNetwork!.rpcUrl, Client());
    String sendTxHash = await client.sendRawTransaction(tx2Send);

    return sendTxHash;
  }

  Future<String?> getAddress(Uint8List textPassword) async {
    final password = keccak256(textPassword);
    nullifyUint8List(textPassword);
    final publicKey =
        await HardwareWalletService().getUncompressedPublicKey(password);

    return publicKey == null
        ? null
        : getEthereumAddressFromPublicKey(publicKey);
  }

  Future<BigInt> getBalance(String wallet, String token) async {
    if (_currentNetwork == null) return BigInt.zero;

    final httpClient = http.Client();
    final Web3Client ethClient = Web3Client(_currentNetwork!.rpcUrl, httpClient);
    final walletAddress = EthereumAddress.fromHex(wallet);

    if (isEthToken(token)) {
      final balance = await ethClient.getBalance(walletAddress);
      return balance.getInWei;
    } else {
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

      return balance.first as BigInt;
    }
  }

  Future<(BigInt, Transaction)?> buildEip1559Transaction(
    String from,
    String token,
    String dst,
    String amount, {
    RewardPercentile rewardPercentile = RewardPercentile.low,
  }) async {
    if (_currentNetwork == null) return null;

    final httpClient = http.Client();
    final Web3Client ethClient = Web3Client(_currentNetwork!.rpcUrl, httpClient);

    final sender = EthereumAddress.fromHex(from);
    final dstAddress = EthereumAddress.fromHex(dst);
    final nonce = await ethClient.getTransactionCount(sender);
    final chainId = await ethClient.getChainId();

    final gasInEIP1559 = await ethClient.getGasInEIP1559();
    if (gasInEIP1559.length != 3) {
      return null;
    }
    final maxPriorityFeePerGas = EtherAmount.inWei(
        gasInEIP1559[rewardPercentile.index].maxPriorityFeePerGas);
    final maxFeePerGas =
        EtherAmount.inWei(gasInEIP1559[rewardPercentile.index].maxFeePerGas);

    if (isEthToken(token)) {
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
          data: Uint8List.fromList([]),
        )
      );
    } else {
      final tokenAddress = EthereumAddress.fromHex(token);
      final contract = DeployedContract(
        ContractAbi.fromJson(erc20Abi, 'ERC20'),
        tokenAddress,
      );

      final transferFunction = contract.function('transfer');
      final amountInt = BigInt.parse(amount);
      final data = transferFunction.encodeCall([dstAddress, amountInt]);

      try {
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
      } catch (e) {
        return null;
      }
    }
  }

  // Network management
  Future<List<Network>> getNetworks() async {
    if (_networks.isNotEmpty) return _networks;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_networksKey);

    if (jsonString == null) {
      _networks = [
        Network(
          id: 'holesky',
          name: 'Ethereum Holesky',
          rpcUrl: 'https://ethereum-holesky-rpc.publicnode.com',
          chainId: 17000,
        ),
      ];
      await _saveNetworks();
    } else {
      final List<dynamic> jsonList = json.decode(jsonString);
      _networks = jsonList.map((e) => Network.fromJson(e)).toList();
    }

    return _networks;
  }

  Future<void> addNetwork(Network network) async {
    if (_networks.any((n) => n.id == network.id)) {
      return;
    }
    _networks.add(network);
    await _saveNetworks();
  }

  Future<void> removeNetwork(String networkId) async {
    _networks.removeWhere((n) => n.id == networkId);
    await _saveNetworks();

    // Clean up tokens for removed network
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_tokensKeyPrefix$networkId');
    _tokensByNetwork.remove(networkId);

    // If current network was removed, switch to first available
    if (_currentNetwork?.id == networkId && _networks.isNotEmpty) {
      await setCurrentNetwork(_networks.first.id);
    }
  }

  Future<void> _saveNetworks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _networks.map((n) => n.toJson()).toList();
    await prefs.setString(_networksKey, json.encode(jsonList));
  }

  Future<Network?> getCurrentNetwork() async {
    if (_currentNetwork != null) return _currentNetwork;

    final prefs = await SharedPreferences.getInstance();
    final networkId = prefs.getString(_currentNetworkKey);

    await getNetworks(); // Ensure networks are loaded

    if (networkId != null) {
      _currentNetwork = _networks.firstWhere(
        (n) => n.id == networkId,
        orElse: () => _networks.first,
      );
    } else if (_networks.isNotEmpty) {
      _currentNetwork = _networks.first;
      await prefs.setString(_currentNetworkKey, _currentNetwork!.id);
    }

    return _currentNetwork;
  }

  Future<void> setCurrentNetwork(String networkId) async {
    final network = _networks.firstWhere((n) => n.id == networkId);
    _currentNetwork = network;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentNetworkKey, networkId);
  }

  // Token management (per network)
  Future<List<Token>> getTokens() async {
    final network = await getCurrentNetwork();
    if (network == null) return [];

    if (_tokensByNetwork.containsKey(network.id)) {
      return _tokensByNetwork[network.id]!;
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_tokensKeyPrefix${network.id}');

    List<Token> tokens;
    if (jsonString == null) {
      tokens = [
        Token(symbol: 'ETH', address: _ethAddress, decimals: 18),
      ];
      _tokensByNetwork[network.id] = tokens;
      await _saveTokens();
    } else {
      final List<dynamic> jsonList = json.decode(jsonString);
      tokens = jsonList.map((e) => Token.fromJson(e)).toList();
      _tokensByNetwork[network.id] = tokens;
    }

    return tokens;
  }

  Future<void> addToken(String address) async {
    final network = await getCurrentNetwork();
    if (network == null) return;

    final tokens = await getTokens();

    if (tokens.any((t) => t.address.toLowerCase() == address.toLowerCase())) {
      return;
    }

    final tokenInfo = await _fetchTokenInfo(address);
    if (tokenInfo == null) return;

    tokens.add(tokenInfo);
    _tokensByNetwork[network.id] = tokens;
    await _saveTokens();
  }

  Future<void> removeToken(String address) async {
    final network = await getCurrentNetwork();
    if (network == null) return;

    final tokens = await getTokens();
    tokens.removeWhere((t) => t.address.toLowerCase() == address.toLowerCase());
    _tokensByNetwork[network.id] = tokens;
    await _saveTokens();
  }

  Future<void> _saveTokens() async {
    final network = await getCurrentNetwork();
    if (network == null) return;

    final prefs = await SharedPreferences.getInstance();
    final tokens = _tokensByNetwork[network.id] ?? [];
    final jsonList = tokens.map((t) => t.toJson()).toList();
    await prefs.setString('$_tokensKeyPrefix${network.id}', json.encode(jsonList));
  }

  Future<Token?> _fetchTokenInfo(String address) async {
    try {
      final network = await getCurrentNetwork();
      if (network == null) return null;

      final Web3Client client = Web3Client(network.rpcUrl, Client());

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