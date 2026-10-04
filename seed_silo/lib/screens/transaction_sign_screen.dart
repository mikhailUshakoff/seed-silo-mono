import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/services/hardware_wallet_service.dart';
import 'package:seed_silo/services/transaction_service.dart';
import 'package:seed_silo/theme/app_theme.dart';
import 'package:seed_silo/utils/nullify.dart';
import 'package:web3dart/web3dart.dart';

enum _SignStatus { waiting, sent, failed }

/// Shows the built transaction, sends it to the device for signing and waits
/// for the user to approve or reject it on the device.
class TransactionSignScreen extends StatefulWidget {
  final Token token;
  final Network network;
  final String walletAddress;
  final Transaction transaction;

  /// Raw password bytes. Consumed (zeroed) once the signing request is sent.
  final Uint8List password;
  final int passwordPos;

  const TransactionSignScreen({
    super.key,
    required this.token,
    required this.network,
    required this.walletAddress,
    required this.transaction,
    required this.password,
    required this.passwordPos,
  });

  @override
  State<TransactionSignScreen> createState() => _TransactionSignScreenState();
}

class _TransactionSignScreenState extends State<TransactionSignScreen> {
  _SignStatus _status = _SignStatus.waiting;
  String? _txHash;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sign();
  }

  @override
  void dispose() {
    // In case signing never started, make sure the password does not linger.
    nullifyUint8List(widget.password);
    super.dispose();
  }

  Future<void> _sign() async {
    try {
      final txHash = await TransactionService().sendTransaction(
        widget.password,
        widget.passwordPos,
        widget.network.rpcUrl,
        widget.transaction,
        widget.network.chainId,
      );
      if (!mounted) return;
      setState(() {
        _txHash = txHash;
        _status = _SignStatus.sent;
      });
    } on HardwareWalletException catch (e) {
      _fail(e.toString());
    } catch (e) {
      _fail('Failed to send transaction: $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _status = _SignStatus.failed;
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

  Widget _detailsCard() {
    final tx = widget.transaction;
    final chainId = widget.network.chainId;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long,
                    size: 16, color: BrandColors.sageBright),
                SizedBox(width: 8),
                Text('Transaction Details',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const Divider(height: 20),
            _detailRow('Wallet address', widget.walletAddress),
            _detailRow('Chain ID', '0x${chainId.toRadixString(16)}'),
            _detailRow('Nonce', '0x${tx.nonce?.toRadixString(16) ?? "null"}'),
            _detailRow('Max Priority Fee Per Gas',
                '0x${tx.maxPriorityFeePerGas?.getInWei.toRadixString(16) ?? "null"} (${TransactionService().convert2Decimal(tx.maxPriorityFeePerGas?.getInWei ?? BigInt.zero, 9)} Gwei)'),
            _detailRow('Max Fee Per Gas',
                '0x${tx.maxFeePerGas?.getInWei.toRadixString(16) ?? "null"} (${TransactionService().convert2Decimal(tx.maxFeePerGas?.getInWei ?? BigInt.zero, 9)} Gwei)'),
            _detailRow('Gas limit',
                '0x${tx.maxGas?.toRadixString(16) ?? "null"} (${tx.maxGas != null ? TransactionService().convert2Decimal(BigInt.from(tx.maxGas!), 9) : "null"} Gwei)'),
            const Divider(height: 20),
            _detailRow('To', tx.to?.with0x ?? "null"),
            _detailRow('Value (in wei)',
                '0x${tx.value?.getInWei.toRadixString(16) ?? "null"}'),
            _detailRow(
                'Data',
                tx.data != null
                    ? tx.data!
                        .map((b) => b.toRadixString(16).padLeft(2, '0'))
                        .join()
                    : "null"),
            _detailRow('Decoded Data',
                '${tx.data != null ? TransactionService().decodeTransactionData(tx.data, widget.token.decimals) : "null"}'),
          ],
        ),
      ),
    );
  }

  Widget _waitingCard() {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Check the transaction on your device and approve or reject it',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failedCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                const Text('Transaction not sent',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(_error ?? ''),
            const SizedBox(height: 16),
            _outlinedButton(
              label: 'Back',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sentCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: BrandColors.verified),
                SizedBox(width: 8),
                Text('Transaction sent',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Hash',
                style: TextStyle(fontSize: 12, color: BrandColors.tan)),
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
            _outlinedButton(
              label: 'Done',
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlinedButton(
      {required String label, required VoidCallback onPressed}) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: BrandColors.sageBright,
        side: const BorderSide(color: BrandColors.borderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The device is still waiting for the user; leaving now would orphan
      // the pending signing request on the serial port.
      canPop: _status != _SignStatus.waiting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sign Transaction'),
          automaticallyImplyLeading: _status != _SignStatus.waiting,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              switch (_status) {
                _SignStatus.waiting => _waitingCard(),
                _SignStatus.failed => _failedCard(),
                _SignStatus.sent => _sentCard(),
              },
              const SizedBox(height: 16),
              _detailsCard(),
            ],
          ),
        ),
      ),
    );
  }
}
