import 'package:flutter/material.dart';
import 'package:seed_silo/screens/preload_screen.dart';
//import 'package:seed_silo/service/hardware_wallet_service.dart';
//import 'dart:typed_data';
//import 'package:web3dart/web3dart.dart';
//import 'package:web3dart/crypto.dart';
//import 'package:convert/convert.dart';
//import 'package:http/http.dart' as http;

//final String rpcUrl = "https://ethereum-holesky-rpc.publicnode.com";

void main() {
  runApp(SeedSiloApp());
}

class SeedSiloApp extends StatelessWidget {
  const SeedSiloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seed Silo',
      theme: ThemeData.dark(),
      home: PreloadScreen(),
    );
  }
}
/*
class ConnectScreen extends StatefulWidget {
  @override
  _ConnectScreenState createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  @override
  void initState() {
    super.initState();
    connectToSerial();
  }

  void connectToSerial() async {
    final result = await HardwareWalletService().getVersion();
        // String hexResponse = buffer.map((byte) => '0x${byte.toRadixString(16).padLeft(2, '0')}').join(', ');
    if (result != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PasswordScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('...')),
    );
  }
}

class PasswordScreen extends StatefulWidget {
  PasswordScreen();

  @override
  _PasswordScreenState createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final TextEditingController passwordController = TextEditingController();
   bool _isBtnDisabled = false;

  void sendPassword() async {
    setState(() {
      _isBtnDisabled = true;
    });

    final result = await HardwareWalletService().getUncompressedPublicKey(passwordController.text);
    if (result != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen(publicKey: result)),
      );
    } else {
      throw Exception('Cannot get public key');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(controller: passwordController, decoration: InputDecoration(labelText: 'Enter Password')),
          ElevatedButton(onPressed: _isBtnDisabled? null : sendPassword, child: Text('Submit')),
        ],
      ),
    );
  }
}

  String getEthereumAddressFromPublicKey(Uint8List publicKey) {
      print("pub key ${hex.encode(publicKey)}");
      Uint8List hashedKey = keccak256(publicKey);
      Uint8List addressBytes = Uint8List.fromList(hashedKey.sublist(12));
      print("address ${hex.encode(addressBytes)}");
      return hex.encode(addressBytes);
  }

class DashboardScreen extends StatefulWidget {
  final Uint8List publicKey;
  final String ethAddress;

  DashboardScreen({required this.publicKey})
  : ethAddress = getEthereumAddressFromPublicKey(publicKey);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Web3Client web3;
  String ethBalance = 'Loading...';

  @override
  void initState() {
    super.initState();
    final httpClient = http.Client();
    web3 = Web3Client(rpcUrl, httpClient);
    getBalance();
  }

  void test() async {
    print("test");
    final transaction = Transaction(
      to: EthereumAddress.fromHex("0x76ef45f325e6e2109e417f9b80ab6d2de31544fe"),
      value: EtherAmount.fromBigInt(EtherUnit.wei, BigInt.parse("0xaa87bee538000")), // Sending 0.01 ETH
      maxGas: 0x5208,//21000, // Standard ETH transfer gas limit
      nonce: 0x9,
      maxFeePerGas:EtherAmount.fromBigInt(EtherUnit.wei, BigInt.parse("0xf4247")),
      maxPriorityFeePerGas: EtherAmount.fromBigInt(EtherUnit.wei, BigInt.parse("0xf4247")),
      data: Uint8List.fromList([]),
    );

    // Convert to RLP-encoded raw transaction (without signing)
    final rawTransaction = transaction.getUnsignedSerialized(chainId: 0x4268);
    print("Raw Transaction: ${bytesToHex(rawTransaction, include0x: false)}");
    print("Raw Transaction length: ${rawTransaction.length}");

    Uint8List txHash = keccak256(rawTransaction);
    print("txHash: ${bytesToHex(txHash, include0x: false)}");
    final sig = await HardwareWalletService().getSignature("", rawTransaction);

    if (sig == null) {
      throw Exception('Cannot get signature');
    }
    // print buffer
    print("esp> r ${sig.r.toRadixString(16)} s ${sig.s.toRadixString(16)} v ${sig.v.toRadixString(16)}");

  }

  Future<void> getBalance() async {
    final address = EthereumAddress.fromHex(widget.ethAddress);
    final balance = await web3.getBalance(address);
    setState(() {
      ethBalance = balance.getValueInUnit(EtherUnit.ether).toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body: Center(
        child:Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ETH Address: 0x${widget.ethAddress}'),
            Text('ETH Balance: $ethBalance ETH'),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SendEthScreen( ethAddress: widget.ethAddress)),
                );
              },
              child: Text('Send ETH'),
            ),
            ElevatedButton(onPressed: () {}, child: Text('Send USDT')),
            ElevatedButton(onPressed: test, child: Text('Test')),
          ],
        ),
      ),
    );
  }
}

class SendEthScreen extends StatefulWidget {
  final String ethAddress;

  SendEthScreen({required this.ethAddress});

  @override
  _SendEthScreenState createState() => _SendEthScreenState();
}

class _SendEthScreenState extends State<SendEthScreen> {
  final TextEditingController addressController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isSendDisabled = false;


  List<dynamic> _encodeEIP1559ToRlp(
    Transaction transaction,
    MsgSignature? signature,
    BigInt chainId,
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

  void sendEth() async {
    setState(() {
      _isSendDisabled = true;
    });

    final httpClient = http.Client();
    final Web3Client ethClient = Web3Client(rpcUrl, httpClient);

    final sender = EthereumAddress.fromHex(widget.ethAddress);
    int nonce = await ethClient.getTransactionCount(sender);

    final toAddress = EthereumAddress.fromHex(addressController.text);

    final chainId = await ethClient.getChainId();

    final maxPriorityFeePerGas = EtherAmount.inWei(BigInt.from(1000000000));
    EtherAmount baseFeePerGas = await ethClient.getGasPrice();
    EtherAmount maxFeePerGas = EtherAmount.inWei(baseFeePerGas.getInWei * BigInt.from(2) + BigInt.from(1000000000));

    final value = EtherAmount.fromBase10String(EtherUnit.wei, amountController.text);
    // Create an unsigned transaction
    final transaction = Transaction(
      to: toAddress,
      value:  value,
      maxGas: 21000, // Standard ETH transfer gas limit
      nonce: nonce,
      maxFeePerGas: maxFeePerGas, // Fetched max fee
      maxPriorityFeePerGas: maxPriorityFeePerGas, // Fetched priority fee
      data: Uint8List.fromList([]),
    );
    final rawTransaction = transaction.getUnsignedSerialized(chainId: chainId.toInt());

    final sig = await HardwareWalletService().getSignature(passwordController.text, rawTransaction);
    if (sig == null) {
      print("Error returned");
      Navigator.pop(context);
      return;
    }

    final signedTransaction = _encodeEIP1559ToRlp(transaction, sig, chainId);
    final signedRlp = encode(signedTransaction);//rlp
    Uint8List tx2Send = Uint8List.fromList(signedRlp);
    if (transaction.isEIP1559) {
       tx2Send = prependTransactionType(0x02, tx2Send);
    }
    String sendTxHash = await ethClient.sendRawTransaction(tx2Send);
    print("Transaction sent! Hash: $sendTxHash");

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Send ETH')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(controller: addressController, decoration: InputDecoration(labelText: 'To Address')),
          TextField(controller: amountController, decoration: InputDecoration(labelText: 'Amount')),
          TextField(controller: passwordController, decoration: InputDecoration(labelText: 'Password')),
          ElevatedButton(onPressed: _isSendDisabled ? null : sendEth, child: Text('Send')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('Back')),
        ],
      ),
    );
  }
}
*/