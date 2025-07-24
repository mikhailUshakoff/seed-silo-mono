import 'package:flutter/material.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/screens/transfer_confirm_screen.dart';
import 'package:seed_silo/widgets/formatted_amount_field.dart';

class TransferScreen extends StatefulWidget {
  final Token token;

  const TransferScreen({super.key, required this.token});

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

  void _onTransferPressed() {
    if (!_formKey.currentState!.validate()) return;

  final destination = _destinationController.text.trim();
  final amount = _amountController.text.replaceAll(' ', '');

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TransferConfirmScreen(
        token: widget.token,
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Address: ${widget.token.address} decimals: ${widget.token.decimals}',
              ),
              TextFormField(
                controller: _destinationController,
                decoration:
                    const InputDecoration(labelText: 'Destination Address'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter destination address'
                    : null,
              ),
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _onTransferPressed,
                child: const Text('Transfer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
