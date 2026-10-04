import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/screens/transaction_sign_screen.dart';
import 'package:seed_silo/services/transaction_service.dart';
import 'package:seed_silo/widgets/submit_slider.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/theme/app_theme.dart';
import 'package:web3dart/web3dart.dart';

class TransferConfirmScreen extends StatefulWidget {
  final Token token;
  final Network network;
  final String destination;
  final String amount;

  const TransferConfirmScreen({
    super.key,
    required this.token,
    required this.network,
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

  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordPosController.dispose();
    super.dispose();
  }

  void _clearPassword() {
    _passwordController.text = '';
    _passwordPosController.text = '';
  }

  void _showError(String message) {
    if (!mounted) return;
    _clearPassword();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    setState(() => _isSubmitting = false);
  }

  Future<void> _submitTransaction() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final passwordPos = int.parse(_passwordPosController.text);

    // Get wallet address
    final walletAddress = await TransactionService().getAddress(
      Uint8List.fromList(_passwordController.text.codeUnits),
      passwordPos,
    );
    if (walletAddress == null) {
      _showError('Can not receive wallet address');
      return;
    }

    final Transaction? tx;
    try {
      tx = await TransactionService().buildEip1559Transaction(
        walletAddress,
        widget.token.address,
        widget.network.rpcUrl,
        widget.destination,
        widget.amount,
      );
    } catch (e) {
      _showError('Can not build transaction: $e');
      return;
    }
    if (tx == null) {
      _showError('Can not build transaction');
      return;
    }

    if (!mounted) return;
    final password = Uint8List.fromList(_passwordController.text.codeUnits);
    _clearPassword();
    setState(() => _isSubmitting = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionSignScreen(
          token: widget.token,
          network: widget.network,
          walletAddress: walletAddress,
          transaction: tx!,
          password: password,
          passwordPos: passwordPos,
        ),
      ),
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required Widget value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: BrandColors.sageBright.withAlpha((0.16 * 255).toInt()),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: BrandColors.sageBright),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 12, color: BrandColors.tan)),
                const SizedBox(height: 2),
                value,
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _summaryRow(
                      icon: Icons.hub,
                      label: 'Network',
                      value: Text(
                        '${widget.network.name} · Chain ID ${widget.network.chainId}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Divider(height: 1),
                    _summaryRow(
                      icon: Icons.token,
                      label: 'Token',
                      value: Text(
                        '${widget.token.symbol} · ${widget.token.decimals} dec · ${widget.token.address}',
                        style: BrandColors.mono
                            .copyWith(fontSize: 12, color: BrandColors.tan),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Divider(height: 1),
                    _summaryRow(
                      icon: Icons.arrow_upward,
                      label: 'Amount',
                      value: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.amount} ${widget.token.symbol}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('to  ',
                                  style: TextStyle(
                                      fontSize: 12, color: BrandColors.tan)),
                              Expanded(
                                child: SelectableText(
                                  widget.destination,
                                  style: BrandColors.mono.copyWith(
                                      fontSize: 12, color: BrandColors.tan),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_isSubmitting) ...[
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline,
                                color: BrandColors.tan),
                          ),
                          obscureText: true,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please enter password'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordPosController,
                          decoration: const InputDecoration(
                            labelText: 'Password Pos',
                            prefixIcon: Icon(Icons.tag, color: BrandColors.tan),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter password position';
                            }
                            final position = int.tryParse(value);
                            if (position == null) {
                              return 'Please enter a valid number';
                            }
                            if (position < 0 || position > 224) {
                              // 256 - 32
                              return 'Password position must be between 0 and 224';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SubmitSlider(
              onSubmit: _submitTransaction,
              loading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }
}
