import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart';
import 'package:convert/convert.dart';
import 'package:http/http.dart' as http;

final String rpcUrl = "https://ethereum-holesky-rpc.publicnode.com";

void main() {
  runApp(SeedSiloApp());
}

class SeedSiloApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seed Silo',
      theme: ThemeData.dark(),
      home: ConnectScreen(),
    );
  }
}

class ConnectScreen extends StatefulWidget {
  @override
  _ConnectScreenState createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  SerialPort? port;

  @override
  void initState() {
    super.initState();
    connectToSerial();
  }

  void connectToSerial() async {
    final availablePorts = SerialPort.availablePorts;
    if (availablePorts.isNotEmpty) {
      port = SerialPort(availablePorts.first);
      if (port!.openReadWrite()) {
        // Configure the serial port
        final portConfig = SerialPortConfig()
          ..baudRate = 115200
          ..bits = 8
          ..stopBits = 1
          ..parity = SerialPortParity.none
          ..setFlowControl(SerialPortFlowControl.none);

        port!.config = portConfig;
        port!.write(Uint8List.fromList([0x1]));

        await Future.delayed(Duration(seconds: 2));

        final buffer = port!.read(1);
        // String hexResponse = buffer.map((byte) => '0x${byte.toRadixString(16).padLeft(2, '0')}').join(', ');
        if (buffer[0] == 0xF0) {
            //reader!.close();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => PasswordScreen(port: port!)),
            );
          }
      }
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
  final SerialPort port;

  PasswordScreen({required this.port});

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
    final password = passwordController.text;
    final keccakHash = keccak256(Uint8List.fromList(password.codeUnits));
    final request = [0x02];
    request.addAll(keccakHash);
    widget.port.write(Uint8List.fromList(request));

    await Future.delayed(Duration(seconds: 2));

    final buffer = widget.port.read(65);
    // String hexResponse = buffer.map((byte) => '0x${byte.toRadixString(16).padLeft(2, '0')}').join(', ');
    if (buffer[0] == 0xF0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen(port: widget.port, publicKey: buffer.sublist(1))),
      );
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
      Uint8List hashedKey = keccak256(publicKey);
      Uint8List addressBytes = Uint8List.fromList(hashedKey.sublist(12));
      return hex.encode(addressBytes);
  }

class DashboardScreen extends StatefulWidget {
  final SerialPort port;
  final Uint8List publicKey;
  final String ethAddress;

  DashboardScreen({required this.port, required this.publicKey})
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
            Text('ETH Address: ${widget.ethAddress}'),
            Text('ETH Balance: $ethBalance ETH'),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SendEthScreen(port: widget.port, ethAddress: widget.ethAddress)),
                );
              },
              child: Text('Send ETH'),
            ),
            ElevatedButton(onPressed: () {}, child: Text('Send USDT')),
          ],
        ),
      ),
    );
  }
}

class SendEthScreen extends StatefulWidget {
  final SerialPort port;
  final String ethAddress;

  SendEthScreen({required this.port, required this.ethAddress});

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
    Uint8List txHash = keccak256(rawTransaction);
    final keccakHash = keccak256(Uint8List.fromList(passwordController.text.codeUnits));
    final request = [0x03];
    request.addAll(keccakHash);
    request.addAll(txHash);
    widget.port.write(Uint8List.fromList(request));

    await Future.delayed(Duration(seconds: 2));

    final buffer = widget.port.read(65);

    if (buffer[0] != 0xF0) {
      print("Error returned");
      Navigator.pop(context);
      return;
    }


    // recover v
    int v = 0;
    final r = buffer.sublist(1, 33);
    final s = buffer.sublist(33, 65);
    for (int i = 0; i < 4; i++) {
      final sig = MsgSignature(
      BigInt.parse(bytesToHex(r),radix: 16),
      BigInt.parse(bytesToHex(s),radix: 16),
      v+27);
      try {
        final recoveredPubkey = ecRecover(txHash, sig);
        final address = getEthereumAddressFromPublicKey(recoveredPubkey);
        if (address == widget.ethAddress) {
          break;
        }

        v += 1;
      } catch (e) {
        v = 10;
        print("get error: $e");
        break;
      }
    }

    if (v < 5) {
      final sig2sign = MsgSignature(
        BigInt.parse(bytesToHex(r),radix: 16),
        BigInt.parse(bytesToHex(s),radix: 16),
        v);
      final signedTransaction = _encodeEIP1559ToRlp(transaction, sig2sign, chainId);
      final signedRlp = encode(signedTransaction);//rlp
      Uint8List tx2Send = Uint8List.fromList(signedRlp);
      if (transaction.isEIP1559) {
         tx2Send = prependTransactionType(0x02, tx2Send);
      }
      String sendTxHash = await ethClient.sendRawTransaction(tx2Send);
      print("Transaction sent! Hash: $sendTxHash with v: $v");
    } else {
      print("Wrong password!");
    }
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
