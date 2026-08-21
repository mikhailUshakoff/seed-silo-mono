import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seed_silo/models/network.dart';
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

    // Get wallet address
    final walletAddress = await TransactionService().getAddress(
      Uint8List.fromList(_passwordController.text.codeUnits),
      int.parse(_passwordPosController.text),
    );

    if (walletAddress == null) {
      _passwordController.text = '';
      _passwordPosController.text = '';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Can not receive wallet address')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    _walletAddress = walletAddress;

    final bTx = await TransactionService().buildEip1559Transaction(
      walletAddress,
      widget.token.address,
      widget.network.rpcUrl,
      widget.destination,
      widget.amount,
    );

    if (bTx == null) {
      _passwordController.text = '';
      _passwordPosController.text = '';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Can not build transaction')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    if (!mounted) return;
    _chainId = widget.network.chainId;
    _transaction = bTx;
    setState(() {
      _showTxInfo = true;
    });

    final sendResult = await TransactionService().sendTransaction(
      Uint8List.fromList(_passwordController.text.codeUnits),
      int.parse(_passwordPosController.text),
      widget.network.rpcUrl,
      _transaction!,
      _chainId!.toInt(),
    );
    _passwordController.text = '';
    _passwordPosController.text = '';
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
                    style: const TextStyle(
                        fontSize: 12, color: BrandColors.tan)),
                const SizedBox(height: 2),
                value,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: BrandColors.tan)),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: BrandColors.mono
                .copyWith(fontSize: 12, color: BrandColors.cream),
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
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _showTxInfo
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.receipt_long,
                                      size: 16, color: BrandColors.sageBright),
                                  const SizedBox(width: 8),
                                  const Text('Transaction Details',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                              const Divider(height: 20),
                              _detailRow('Wallet address',
                                  _walletAddress ?? "null"),
                              _detailRow('Chain ID',
                                  '0x${_chainId?.toRadixString(16) ?? "null"}'),
                              _detailRow('Nonce',
                                  '0x${_transaction!.nonce?.toRadixString(16) ?? "null"}'),
                              _detailRow('Max Priority Fee Per Gas',
                                  '0x${_transaction!.maxPriorityFeePerGas?.getInWei.toRadixString(16) ?? "null"} (${TransactionService().convert2Decimal(_transaction!.maxPriorityFeePerGas?.getInWei ?? BigInt.zero, 9)} Gwei)'),
                              _detailRow('Max Fee Per Gas',
                                  '0x${_transaction!.maxFeePerGas?.getInWei.toRadixString(16) ?? "null"} (${TransactionService().convert2Decimal(_transaction!.maxFeePerGas?.getInWei ?? BigInt.zero, 9)} Gwei)'),
                              _detailRow('Gas limit',
                                  '0x${_transaction!.maxGas?.toRadixString(16) ?? "null"} (${_transaction!.maxGas != null ? TransactionService().convert2Decimal(BigInt.from(_transaction!.maxGas!), 9) : "null"} Gwei)'),
                              const Divider(height: 20),
                              _detailRow(
                                  'To', _transaction!.to?.with0x ?? "null"),
                              _detailRow('Value (in wei)',
                                  '0x${_transaction!.value?.getInWei.toRadixString(16) ?? "null"}'),
                              _detailRow(
                                  'Data',
                                  _transaction!.data != null
                                      ? _transaction!.data!
                                          .map((b) =>
                                              b.toRadixString(16).padLeft(2, '0'))
                                          .join()
                                      : "null"),
                              _detailRow('Decoded Data',
                                  '${_transaction!.data != null ? TransactionService().decodeTransactionData(_transaction!.data, widget.token.decimals) : "null"}'),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
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
                        enabled: _txHash == null && _isSubmitting == false,
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
                        enabled: _txHash == null && _isSubmitting == false,
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
            if (_txHash == null) ...[
              SubmitSlider(
                onSubmit: _submitTransaction,
              ),
            ] else ...[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: BrandColors.verified),
                          const SizedBox(width: 8),
                          const Text('Transaction sent',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Hash',
                          style: TextStyle(
                              fontSize: 12, color: BrandColors.tan)),
                      const SizedBox(height: 4),
                      SelectableText(
                        _txHash ?? '',
                        style: BrandColors.mono.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _copyHash,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Hash'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BrandColors.sageBright,
                          side: const BorderSide(
                              color: BrandColors.borderStrong),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
