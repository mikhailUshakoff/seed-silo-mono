import 'package:flutter/material.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/screens/transfer_confirm_screen.dart';
import 'package:seed_silo/widgets/formatted_amount_field.dart';
import 'package:seed_silo/theme/app_theme.dart';

class TransferScreen extends StatefulWidget {
  final Token token;
  final Network network;

  const TransferScreen({super.key, required this.token, required this.network});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _destinationController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onTransferPressed() async {
    if (!_formKey.currentState!.validate()) return;

    final destination = _destinationController.text.trim();
    final amount = _amountController.text.replaceAll(' ', '');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransferConfirmScreen(
          token: widget.token,
          network: widget.network,
          destination: destination,
          amount: amount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transfer ${widget.token.symbol}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: BrandColors.sageBright
                              .withAlpha((0.16 * 255).toInt()),
                          child: Text(
                            widget.token.symbol.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: BrandColors.sageBright,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: BrandColors.espressoSurfaceHigh,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: BrandColors.espressoSurface,
                                  width: 2),
                            ),
                            child: const Icon(Icons.hub,
                                size: 11, color: BrandColors.sageBright),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.token.symbol,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: BrandColors.espressoSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: BrandColors.borderStrong),
                                ),
                                child: Text(
                                  '${widget.token.decimals} dec',
                                  style: const TextStyle(
                                      fontSize: 11, color: BrandColors.tan),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'on ${widget.network.name} · Chain ID ${widget.network.chainId}',
                            style: const TextStyle(
                                fontSize: 12, color: BrandColors.tan),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.token.address,
                            style: BrandColors.mono.copyWith(
                              fontSize: 12,
                              color: BrandColors.tan,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _destinationController,
                      style: BrandColors.mono.copyWith(fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Destination Address',
                        hintText: '0x...',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined,
                            color: BrandColors.tan),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please enter destination address'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    FormattedAmountField(
                      controller: _amountController,
                      label: 'Amount',
                      decimals: widget.token.decimals,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter amount';
                        }
                        final clean = value.replaceAll(' ', '');
                        final amount = double.tryParse(clean);
                        if (amount == null || amount <= 0) {
                          return 'Enter valid amount';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _onTransferPressed,
                icon: const Icon(Icons.arrow_upward, size: 18),
                label: const Text('Review Transfer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
