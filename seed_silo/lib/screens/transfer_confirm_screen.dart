import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nonceController = TextEditingController();

  String? _txHash;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _nonceController.dispose();
    super.dispose();
  }

  Future<void> _submitTransaction() async {
    if (_isSubmitting) return;

    final password = _passwordController.text.trim();
    final nonceStr = _nonceController.text.trim();

    if (password.isEmpty || nonceStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password and nonce are required')),
      );
      return;
    }

    final nonce = int.tryParse(nonceStr);
    if (nonce == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid nonce')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    await Future.delayed(const Duration(seconds: 3)); // Simulate signing and sending

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
            Text('Token: ${widget.token.symbol}'),
            Text('Destination: ${widget.destination}'),
            Text('Amount: ${widget.amount}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              enabled: _txHash == null,
            ),
            TextFormField(
              controller: _nonceController,
              decoration: const InputDecoration(labelText: 'Nonce'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: _txHash == null,
            ),
            const SizedBox(height: 24),

            if (_txHash == null) ...[
              SubmitSlider(
                onSubmit: _submitTransaction,
              ),
            ] else ...[
              const Text('Transaction submitted!', style: TextStyle(fontWeight: FontWeight.bold)),
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
