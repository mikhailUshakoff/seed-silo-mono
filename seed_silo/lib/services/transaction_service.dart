import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:seed_silo/services/hardware_wallet_service.dart';
import 'package:seed_silo/services/network_service.dart';
import 'package:seed_silo/services/token_service.dart';
import 'package:seed_silo/utils/nullify.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/models/token.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

/// rewardPercentileIndex is an integer that represents which percentile of priority fees
/// to use when calculating the gas fees for the transaction. In EIP-1559, priority fees
/// are determined by percentile ranges. The available values are:
/// low - 25th percentile
/// medium - 50th percentile
/// high - 75th percentile
/// These indices are used to select the corresponding priority fee from the list of fees
/// returned by the getGasInEIP1559 function.
enum RewardPercentile { low, medium, high }

class TransactionService {
  static final TransactionService _instance = TransactionService._internal();
  factory TransactionService() => _instance;
  TransactionService._internal();

  static const String _tokensKey = 'tokens';

  static const String ethAddress =
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

  bool isEthToken(String token) => token == ethAddress;

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

    list.add([]); // access list

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
      EthereumAddress.fromHex(
          ethAddress), // dummy address, not used for decoding
    );

    final function = contract.function('transfer');
    final selector = data.sublist(0, 4);
    final functionName = !listEquals(function.selector, selector)
        ? bytesToHex(data.sublist(0, 4), include0x: true)
        : "transfer (0xa9059cbb)";

    final paramData = data.sublist(4); // skip selector
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

    // Add decimal point
    String formatted;
    if (str.length <= decimals) {
      final padded = str.padLeft(decimals, '0');
      formatted = "0.$padded";
    } else {
      final insertPoint = str.length - decimals;
      formatted =
          "${str.substring(0, insertPoint)}.${str.substring(insertPoint)}";
    }

    // Split into integer and fractional parts
    final parts = formatted.split('.');
    final integerPart = parts[0];
    final fractionalPart = parts.length > 1 ? parts[1] : '';

    // Format integer part with thousand separators
    final formattedInteger = _formatWithSeparators(integerPart);

    // Format fractional part in groups of 3 digits
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
    final signedRlp = encode(signedTransaction); //rlp
    Uint8List tx2Send = Uint8List.fromList(signedRlp);
    // tx is EIP1559 add prefix 0x02
    tx2Send = prependTransactionType(0x02, tx2Send);

final rpcUrl = (await NetworkService().getCurrentNetwork()).rpcUrl;
    final Web3Client client = Web3Client(rpcUrl, Client());
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
    final httpClient = http.Client();
    final rpcUrl = (await NetworkService().getCurrentNetwork()).rpcUrl;
    final Web3Client ethClient = Web3Client(rpcUrl, httpClient);
    final walletAddress = EthereumAddress.fromHex(wallet);
    if (isEthToken(token)) {
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
    final httpClient = http.Client();
    final rpcUrl = (await NetworkService().getCurrentNetwork()).rpcUrl;
    final Web3Client ethClient = Web3Client(rpcUrl, httpClient);

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
      // Build ETH transfer
      final value = EtherAmount.fromBase10String(EtherUnit.wei, amount);
      return (
        chainId,
        Transaction(
          to: dstAddress,
          value: value,
          maxGas: 21000, // Standard ETH transfer gas limit
          nonce: nonce,
          maxFeePerGas: maxFeePerGas,
          maxPriorityFeePerGas: maxPriorityFeePerGas,
          data: Uint8List.fromList([]),
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

  Future<List<Token>> getTokens() async {
    if (_tokens.isNotEmpty) return _tokens;

    _tokens = await TokenService().getTokens();

    return _tokens;
  }

  Future<bool> addToken(String address) async {
    // Check if already added
    if (_tokens.any((t) => t.address.toLowerCase() == address.toLowerCase())) {
      return false;
    }

    // Fetch token info (symbol, decimals) from blockchain
    final tokenInfo = await fetchTokenInfo(address);
    if (tokenInfo == null) return false; // handle failure silently

    _tokens.add(tokenInfo);
    await _saveTokens();
    return true;
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

  Future<Token?> fetchTokenInfo(String address) async {
    try {
      final rpcUrl = (await NetworkService().getCurrentNetwork()).rpcUrl;
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