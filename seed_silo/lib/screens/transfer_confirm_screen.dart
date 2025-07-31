import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seed_silo/services/eth_wallet_service.dart';
import 'package:seed_silo/widgets/submit_slider.dart';
import 'package:seed_silo/models/token.dart';
import 'package:web3dart/web3dart.dart';

class TransferConfirmScreen extends StatefulWidget {
  final Token token;
  final String destination;
  final String amount;

  const TransferConfirmScreen({
    super.key,
    required this.token,
    required this.destination,
    required this.amount,
  });

  @override
  State<TransferConfirmScreen> createState() => _TransferConfirmScreenState();
}

class _TransferConfirmScreenState extends State<TransferConfirmScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordPosController =
      TextEditingController(text: '1');

  String? _txHash;
  bool _isSubmitting = false;
  Transaction? _transaction;
  BigInt? _chainId;
  bool _showTxInfo = false;
  String? _walletAddress;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordPosController.dispose();
    super.dispose();
  }

  Future<void> _submitTransaction() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final walletAddress = await EthWalletService()
        .getAddress(Uint8List.fromList(_passwordController.text.codeUnits));

    if (walletAddress == null) {
      _passwordController.text = '';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Can not receive wallet address')),
      );

      setState(() => _isSubmitting = false);
      return;
    }

    _walletAddress = walletAddress;

    final bTx = await EthWalletService().buildEip1559Transaction(
      walletAddress,
      widget.token.address,
      widget.destination,
      widget.amount,
    );

    if (bTx == null) {
      _passwordController.text = '';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Can not build transaction')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    if (!mounted) return;
    _chainId = bTx.$1;
    _transaction = bTx.$2;
    setState(() {
      _showTxInfo = true;
    });

    final sendResult = await EthWalletService().sendTransaction(
      Uint8List.fromList(_passwordController.text.codeUnits),
      _transaction!,
      _chainId!.toInt(),
    );
    _passwordController.text = '';
    String txHash = sendResult ?? "0x";

    setState(() {
      _txHash = txHash;
    });
  }

  void _copyHash() {
    if (_txHash != null) {
      Clipboard.setData(ClipboardData(text: _txHash!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction hash copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'Token: ${widget.token.symbol} decimals: ${widget.token.decimals}',
            ),
            Text(
              'Destination: ${widget.destination}',
            ),
            Text(
              'Amount: ${widget.amount}',
            ),
            const SizedBox(height: 16),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _showTxInfo
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wallet address: $_walletAddress'),
                        const Text('Transaction Details:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Chain ID: ${_chainId?.toRadixString(16) ?? "null"}'),
                        Text('To: ${_transaction!.to?.hex ?? "null"}'),
                        Text('From: ${_transaction!.from?.hex ?? "null"}'),
                        Text(
                            'Nonce: ${_transaction!.nonce?.toRadixString(16) ?? "null"}'),
                        Text(
                            'Gas: ${_transaction!.maxGas?.toRadixString(16) ?? "null"}'),
                        Text(
                            'Gas Price: ${_transaction!.gasPrice?.getInWei.toRadixString(16) ?? "null"}'),
                        Text(
                            'Max Fee Per Gas: ${_transaction!.maxFeePerGas?.getInWei.toRadixString(16) ?? "null"}'),
                        Text(
                            'Max Priority Fee Per Gas: ${_transaction!.maxPriorityFeePerGas?.getInWei.toRadixString(16) ?? "null"}'),
                        Text(
                            'Value (in wei): ${_transaction!.value?.getInWei.toRadixString(16) ?? "null"}'),
                        Text(
                            'Data: ${_transaction!.data != null ? _transaction!.data!.map((b) => b.toRadixString(16).padLeft(2, '0')).join() : "null"}'),
                        Text(
                            'Decoded Data:\n${_transaction!.data != null ? EthWalletService().decodeTransactionData(_transaction!.data) : "null"}'),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    enabled: _txHash == null && _isSubmitting == false,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please enter password'
                        : null,
                  ),
                  TextFormField(
                    controller: _passwordPosController,
                    decoration:
                        const InputDecoration(labelText: 'Password Pos'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    enabled: _txHash == null && _isSubmitting == false,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please enter password position'
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_txHash == null) ...[
              SubmitSlider(
                onSubmit: _submitTransaction,
              ),
            ] else ...[
              const SizedBox(height: 8),
              SelectableText('Hash: $_txHash'),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _copyHash,
                icon: const Icon(Icons.copy),
                label: const Text('Copy Hash'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}