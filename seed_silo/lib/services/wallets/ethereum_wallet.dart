import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/services/hardware_wallet_service.dart';
import 'package:seed_silo/services/token_service.dart';
import 'package:seed_silo/services/wallets/base_wallet_service.dart';
import 'package:seed_silo/utils/nullify.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

/// Ethereum/EVM-compatible wallet implementation
class EthereumWallet extends BaseWalletService {
  static final EthereumWallet _instance = EthereumWallet._internal();
  factory EthereumWallet() => _instance;
  EthereumWallet._internal();

  final _hardwareWalletService = HardwareWalletService();

  static const String _nativeTokenAddress = 'native';


  // ERC20 ABI for Ethereum-based tokens
  static const String erc20Abi = '''
      [
        {"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"type":"function"},
        {"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"},
        {"constant":true,"inputs":[{"name":"owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"type":"function"},
        {"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"}
      ]
    ''';

  // Token cache per network
  List<Token>? _cachedTokens;

  @override
  String? rpcUrl;

  @override
  String? networkId;

  @override
  Token getDefaultNativeToken() {
    return Token(
      symbol: 'ETH',
      address: _nativeTokenAddress,
      decimals: 18,
    );
  }

  @override
  bool isNativeToken(String tokenAddress) =>
      tokenAddress.toLowerCase() == _nativeTokenAddress.toLowerCase();

  @override
  String getAddressFromPublicKey(Uint8List publicKey) {
    Uint8List hashedKey = keccak256(publicKey);
    Uint8List addressBytes = Uint8List.fromList(hashedKey.sublist(12));
    return '0x${hex.encode(addressBytes)}';
  }

  @override
  Future<String?> getAddress(Uint8List textPassword) async {
    final password = keccak256(textPassword);
    nullifyUint8List(textPassword);
    final publicKey = await _hardwareWalletService.getUncompressedPublicKey(password);

    return publicKey == null ? null : getAddressFromPublicKey(publicKey);
  }

  // Token management methods
  @override
  Future<List<Token>> getTokens() async {
    if (_cachedTokens != null) return _cachedTokens!;

    final currentNetworkId = networkId;
    if (currentNetworkId == null) return [];

    final tokens = <Token>[getDefaultNativeToken()];
    final tokenAddresses = await TokenService.getTokenKeysForNetwork(currentNetworkId);

    for (final address in tokenAddresses) {
      final token = await TokenService.loadTokenForNetwork(currentNetworkId, address);
      if (token != null) {
        tokens.add(token);
      }
    }

    _cachedTokens = tokens;
    return _cachedTokens!;
  }

  @override
  Future<bool> addToken(String address) async {
    final tokens = await getTokens();

    // Check if already exists
    if (tokens.any((t) => t.address.toLowerCase() == address.toLowerCase())) {
      return false;
    }

    // Fetch token info from blockchain
    final tokenInfo = await fetchTokenInfo(address);
    if (tokenInfo == null) return false;

    // Save individual token
    final currentNetworkId = networkId;
    if (currentNetworkId != null) {
      await TokenService.saveTokenForNetwork(currentNetworkId, address, tokenInfo);
    }

    tokens.add(tokenInfo);
    _cachedTokens = tokens;
    return true;
  }

  @override
  Future<void> removeToken(String address) async {
    final tokens = await getTokens();
    tokens.removeWhere((t) => t.address.toLowerCase() == address.toLowerCase());

    // Remove individual token
    final currentNetworkId = networkId;
    if (currentNetworkId != null) {
      await TokenService.removeTokenForNetwork(currentNetworkId, address);
    }

    _cachedTokens = tokens;
  }

  @override
  void clearTokenCache() {
    _cachedTokens = null;
  }

  @override
  Future<BigInt> getBalance(String walletAddress, String tokenAddress) async {
    if (rpcUrl == null) return BigInt.zero;

    final client = Web3Client(rpcUrl!, Client());
    final wallet = EthereumAddress.fromHex(walletAddress);

    try {
      if (isNativeToken(tokenAddress)) {
        final balance = await client.getBalance(wallet);
        return balance.getInWei;
      } else {
        final token = EthereumAddress.fromHex(tokenAddress);
        final contract = DeployedContract(
          ContractAbi.fromJson(erc20Abi, 'ERC20'),
          token,
        );

        final balanceFunction = contract.function('balanceOf');
        final balance = await client.call(
          contract: contract,
          function: balanceFunction,
          params: [wallet],
        );

        return balance.first as BigInt;
      }
    } catch (e) {
      return BigInt.zero;
    }
  }

  @override
  Future<TransactionData?> buildTransaction({
    required String from,
    required String to,
    required String amount,
    required String tokenAddress,
    FeeLevel feeLevel = FeeLevel.medium,
  }) async {
    if (rpcUrl == null) return null;

    final txData = await buildTransactionWithRpc(
      from: from,
      to: to,
      amount: amount,
      tokenAddress: tokenAddress,
      rpcUrl: rpcUrl!,
      feeLevel: feeLevel,
    );

    if (txData == null) return null;

    return TransactionData(
      rawTransaction: txData.$1,
      chainId: txData.$2,
    );
  }

  Future<(Transaction, int)?> buildTransactionWithRpc({
    required String from,
    required String to,
    required String amount,
    required String tokenAddress,
    required String rpcUrl,
    FeeLevel feeLevel = FeeLevel.medium,
  }) async {
    final client = Web3Client(rpcUrl, Client());
    final sender = EthereumAddress.fromHex(from);
    final dstAddress = EthereumAddress.fromHex(to);
    final nonce = await client.getTransactionCount(sender);
    final chainId = (await client.getChainId()).toInt();

    final gasInEIP1559 = await client.getGasInEIP1559();
    if (gasInEIP1559.length != 3) return null;

    final maxPriorityFeePerGas = EtherAmount.inWei(
        gasInEIP1559[feeLevel.index].maxPriorityFeePerGas);
    final maxFeePerGas =
        EtherAmount.inWei(gasInEIP1559[feeLevel.index].maxFeePerGas);

    if (isNativeToken(tokenAddress)) {
      final value = EtherAmount.fromBase10String(EtherUnit.wei, amount);
      return (
        Transaction(
          to: dstAddress,
          value: value,
          maxGas: 21000,
          nonce: nonce,
          maxFeePerGas: maxFeePerGas,
          maxPriorityFeePerGas: maxPriorityFeePerGas,
          data: Uint8List.fromList([]),
        ),
        chainId,
      );
    } else {
      final token = EthereumAddress.fromHex(tokenAddress);
      final contract = DeployedContract(
        ContractAbi.fromJson(erc20Abi, 'ERC20'),
        token,
      );

      final transferFunction = contract.function('transfer');
      final amountInt = BigInt.parse(amount);
      final data = transferFunction.encodeCall([dstAddress, amountInt]);

      try {
        final gasLimit = await client.estimateGas(
          sender: sender,
          to: token,
          value: EtherAmount.zero(),
          data: data,
        );

        final adjustedGas = (gasLimit.toDouble() * 1.2).ceil();

        return (
          Transaction(
            to: token,
            value: EtherAmount.zero(),
            data: data,
            maxGas: adjustedGas,
            nonce: nonce,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
          ),
          chainId,
        );
      } catch (e) {
        return null;
      }
    }
  }

  @override
  Future<String?> sendTransaction(
    Uint8List textPassword,
    TransactionData transaction,
  ) async {
    if (rpcUrl == null) return null;

    return await sendTransactionWithRpc(
      textPassword,
      transaction.rawTransaction as Transaction,
      transaction.chainId,
      rpcUrl!,
    );
  }

  Future<String?> sendTransactionWithRpc(
    Uint8List textPassword,
    Transaction tx,
    int chainId,
    String rpcUrl,
  ) async {
    if (!tx.isEIP1559) {
      nullifyUint8List(textPassword);
      return null;
    }

    final password = keccak256(textPassword);
    nullifyUint8List(textPassword);

    final rawTransaction = tx.getUnsignedSerialized(chainId: chainId);
    final sig = await _hardwareWalletService.getSignature(password, rawTransaction);

    if (sig == null) return null;

    final signedTransaction = _encodeEIP1559ToRlp(tx, sig, chainId);
    final signedRlp = encode(signedTransaction);
    Uint8List tx2Send = Uint8List.fromList(signedRlp);
    tx2Send = prependTransactionType(0x02, tx2Send);

    final client = Web3Client(rpcUrl, Client());
    String sendTxHash = await client.sendRawTransaction(tx2Send);

    return sendTxHash;
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

  @override
  String? decodeTransactionData(Uint8List? data, int decimals) {
    if (data == null || data.isEmpty) return null;

    final contract = DeployedContract(
      ContractAbi.fromJson(erc20Abi, 'ERC20'),
      EthereumAddress.fromHex(_nativeTokenAddress),
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

  @override
  String convert2Decimal(BigInt value, int decimals) {
    String str = value.toRadixString(10);

    String formatted;
    if (str.length <= decimals) {
      final padded = str.padLeft(decimals, '0');
      formatted = "0.$padded";
    } else {
      final insertPoint = str.length - decimals;
      formatted = "${str.substring(0, insertPoint)}.${str.substring(insertPoint)}";
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

  @override
  Future<Token?> fetchTokenInfo(String address) async {
    if (rpcUrl == null) return null;

    try {
      final client = Web3Client(rpcUrl!, Client());
      final tokenAddress = EthereumAddress.fromHex(address);

      final contract = DeployedContract(
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