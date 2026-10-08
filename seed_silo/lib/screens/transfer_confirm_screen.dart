import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/screens/transaction_sign_screen.dart';
import 'package:seed_silo/services/hardware_wallet_service.dart';
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
    final String walletAddress;
    try {
      walletAddress = await TransactionService().getAddress(
        Uint8List.fromList(_passwordController.text.codeUnits),
        passwordPos,
      );
    } on HardwareWalletException catch (e) {
      _showError('Can not receive wallet address: $e');
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

  /// [TransferConfirmScreen.amount] is in base units (wei); show it in token
  /// units.
  String get _formattedAmount {
    final value = BigInt.tryParse(widget.amount);
    return value == null
        ? widget.amount
        : TransactionService().formatAmount(value, widget.token.decimals);
  }

  static const _sectionTitleStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    color: BrandColors.tan,
  );

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required Widget value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('YOU ARE SENDING', style: _sectionTitleStyle),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: _formattedAmount,
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: '  ${widget.token.symbol}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: BrandColors.tan),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    _summaryRow(
                      icon: Icons.arrow_outward,
                      label: 'To',
                      value: SelectableText(
                        widget.destination,
                        style: BrandColors.mono
                            .copyWith(fontSize: 13, color: BrandColors.cream),
                      ),
                    ),
                    const Divider(height: 1),
                    _summaryRow(
                      icon: Icons.token,
                      label: 'Token',
                      value: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: widget.token.symbol,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: BrandColors.cream),
                          ),
                          TextSpan(
                            text: '  ·  ${widget.token.decimals} decimals'
                                '  ·  ${widget.token.address}',
                            style: BrandColors.mono
                                .copyWith(fontSize: 11, color: BrandColors.tan),
                          ),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Divider(height: 1),
                    _summaryRow(
                      icon: Icons.hub,
                      label: 'Network',
                      value: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: widget.network.name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: BrandColors.cream),
                          ),
                          TextSpan(
                            text: '  ·  Chain ID ${widget.network.chainId}',
                            style: const TextStyle(
                                fontSize: 12, color: BrandColors.tan),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Kept in the tree (only disabled) while submitting: removing it
            // shifts the slider's index in the ListView, which disposes the
            // slider mid-submit and crashes slide_to_act's reset().
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon:
                              Icon(Icons.lock_outline, color: BrandColors.tan),
                        ),
                        obscureText: true,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter password'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordPosController,
                        enabled: !_isSubmitting,
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
