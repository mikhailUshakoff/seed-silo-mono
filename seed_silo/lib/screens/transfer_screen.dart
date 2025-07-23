import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seed_silo/models/token.dart';
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
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordPosController = TextEditingController();

  @override
  void dispose() {
    _destinationController.dispose();
    _amountController.dispose();
    _passwordController.dispose();
    _passwordPosController.dispose();
    super.dispose();
  }

  void _onTransferPressed() {
    if (!_formKey.currentState!.validate()) return;

    // TODO: Implement transfer logic here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transfer placeholder: Implement logic')),
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
                  if (value == null || value.isEmpty)
                    return 'Please enter amount';
                  final clean = value.replaceAll(' ', '');
                  final amount = double.tryParse(clean);
                  if (amount == null || amount <= 0)
                    return 'Enter valid amount';
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter password'
                    : null,
              ),
              TextFormField(
                controller: _passwordPosController,
                decoration: const InputDecoration(labelText: 'Password Pos'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter password position'
                    : null,
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
