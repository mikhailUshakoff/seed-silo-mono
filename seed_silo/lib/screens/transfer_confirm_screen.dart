import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seed_silo/services/eth_wallet_service.dart';
import 'package:seed_silo/widgets/submit_slider.dart';
import 'package:seed_silo/models/token.dart';

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
  final TextEditingController _passwordPosController = TextEditingController();

  String? _txHash;
  bool _isSubmitting = false;
  bool _isBalanceLoading = true;
  BigInt? _balance;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final balance = await EthWalletService().getBalance(widget.token.address);
    if (mounted) {
      setState(() {
        _balance = balance;
        _isBalanceLoading = false;
      });
    }
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

    _passwordController.text = '';

    setState(() => _isSubmitting = true);

    await Future.delayed(
        const Duration(seconds: 5)); // Simulate signing and sending

    // TODO: Replace with actual sign/send logic
    const fakeHash = '0xabc123aaadeadbeef';

    setState(() {
      _txHash = fakeHash;
      _isSubmitting = false;
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
            Text('Wallet address: ${EthWalletService().walletAddress}'),
            if (_isBalanceLoading)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Loading balance...'),
                ],
              )
            else
              Text('Balance: ${_balance.toString()}'),
            Text('Token: ${widget.token.symbol}'),
            Text('Destination: ${widget.destination}'),
            Text('Amount: ${widget.amount}'),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    enabled: _txHash == null,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please enter password'
                        : null,
                  ),
                  TextFormField(
                    controller: _passwordPosController,
                    decoration: const InputDecoration(labelText: 'Password Pos'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    enabled: _txHash == null,
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
                enabled: !_isBalanceLoading,
              ),
            ] else ...[
              const Text('Transaction submitted!',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
