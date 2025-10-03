import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seed_silo/services/network_service.dart';
import 'package:seed_silo/services/wallets/ethereum_wallet.dart';
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
  final _networkService = NetworkService();

  String? _txHash;
  bool _isSubmitting = false;
  Transaction? _transaction;
  int? _chainId;
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

    // Get current wallet
    final wallet = await _networkService.getCurrentWallet();
    if (wallet == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No wallet available')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    // Get wallet address
    final walletAddress = await wallet.getAddress(
      Uint8List.fromList(_passwordController.text.codeUnits),
    );

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

    // Build transaction (Ethereum-specific for now)
    if (wallet is! EthereumWallet) {
      _passwordController.text = '';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Ethereum networks are supported')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    final bTx = await wallet.buildTransactionWithRpc(
      from: walletAddress,
      to: widget.destination,
      amount: widget.amount,
      tokenAddress: widget.token.address,
      rpcUrl: wallet.rpcUrl!,
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
    _transaction = bTx.$1;
    _chainId = bTx.$2;
    setState(() {
      _showTxInfo = true;
    });

    // Send transaction
    final sendResult = await wallet.sendTransactionWithRpc(
      Uint8List.fromList(_passwordController.text.codeUnits),
      _transaction!,
      _chainId!,
      wallet.rpcUrl!,
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
                        Text(
                            'Chain ID: 0x${_chainId?.toRadixString(16) ?? "null"}'),
                        Text(
                            'Nonce: 0x${_transaction!.nonce?.toRadixString(16) ?? "null"}'),
                        Text(
                            'Max Priority Fee Per Gas: 0x${_transaction!.maxPriorityFeePerGas?.getInWei.toRadixString(16) ?? "null"} (${EthereumWallet().convert2Decimal(_transaction!.maxPriorityFeePerGas?.getInWei ?? BigInt.zero, 9)} Gwei)'),
                        Text(
                            'Max Fee Per Gas: 0x${_transaction!.maxFeePerGas?.getInWei.toRadixString(16) ?? "null"} (${EthereumWallet().convert2Decimal(_transaction!.maxFeePerGas?.getInWei ?? BigInt.zero, 9)} Gwei)'),
                        Text(
                            'Gas limit: 0x${_transaction!.maxGas?.toRadixString(16) ?? "null"} (${_transaction!.maxGas != null ? EthereumWallet().convert2Decimal(BigInt.from(_transaction!.maxGas!), 9) : "null"} Gwei)'),
                        Text('------------'),
                        Text('To: ${_transaction!.to?.hex ?? "null"}'),
                        Text(
                            'Value (in wei): 0x${_transaction!.value?.getInWei.toRadixString(16) ?? "null"}'),
                        Text(
                            'Data: ${_transaction!.data != null ? _transaction!.data!.map((b) => b.toRadixString(16).padLeft(2, '0')).join() : "null"}'),
                        Text(
                            'Decoded Data:\n${_transaction!.data != null ? EthereumWallet().decodeTransactionData(_transaction!.data, widget.token.decimals) : "null"}'),
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