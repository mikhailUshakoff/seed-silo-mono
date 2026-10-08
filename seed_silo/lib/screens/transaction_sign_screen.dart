import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/screens/preload_screen.dart';
import 'package:seed_silo/services/hardware_wallet_service.dart';
import 'package:seed_silo/services/transaction_service.dart';
import 'package:seed_silo/theme/app_theme.dart';
import 'package:seed_silo/utils/nullify.dart';
import 'package:wallet/wallet.dart' show EtherAmount;
import 'package:web3dart/web3dart.dart';

enum _SignStatus { waiting, sent, rejected, failed }

/// Firmware code for "Transaction was rejected by user" (CORE_ERR_TX_REJECTED).
const int _txRejectedCode = HardwareWalletService.txRejectedCode;
const String _erc20TransferSelector = 'a9059cbb';

/// Shows the built transaction and requests its signature from the device.
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

class _TransactionSignScreenState extends State<TransactionSignScreen>
    with SingleTickerProviderStateMixin {
  _SignStatus _status = _SignStatus.waiting;
  String? _txHash;
  String? _error;
  bool _cancelling = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _sign();
  }

  @override
  void dispose() {
    _pulse.dispose();
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
      _finish(_SignStatus.sent, txHash: txHash);
    } on HardwareWalletCancelledException catch (e) {
      if (!mounted) return;
      if (e.deviceResponded) {
        Navigator.of(context).pop();
      } else {
        // Device did not confirm the interrupt; reconnect from preload screen.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PreloadScreen()),
          (_) => false,
        );
      }
    } on HardwareWalletException catch (e) {
      _finish(
        e.code == _txRejectedCode ? _SignStatus.rejected : _SignStatus.failed,
        error: e.toString(),
      );
    } catch (e) {
      _finish(_SignStatus.failed, error: 'Failed to send transaction: $e');
    }
  }

  /// Asks the device to drop the pending request; the screen pops once the
  /// device has been interrupted (see [_sign]).
  void _cancel() {
    if (_cancelling || _status != _SignStatus.waiting) return;
    setState(() => _cancelling = true);
    HardwareWalletService().cancelSignature();
  }

  void _finish(_SignStatus status, {String? txHash, String? error}) {
    if (!mounted) return;
    _pulse.stop();
    setState(() {
      _status = status;
      _txHash = txHash;
      _error = error;
    });
  }

  void _copy(String value, String what) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what copied')),
    );
  }

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  /// Whole bytes, like the device prints them (`%02x` per byte): 0x88bb0 is
  /// shown as 0x088bb0. Zero is an empty RLP value, which the device shows
  /// as 0x0.
  String _hex(BigInt? v) {
    if (v == null) return '—';
    if (v == BigInt.zero) return '0x0';
    final digits = v.toRadixString(16);
    return '0x${digits.length.isOdd ? '0$digits' : digits}';
  }

  String _decimal(BigInt value, int decimals) =>
      TransactionService().formatAmount(value, decimals);

  String _gwei(EtherAmount? v) =>
      v == null ? '—' : '${_decimal(v.getInWei, 9)} Gwei';

  String _calldata(Uint8List? data) => data == null || data.isEmpty
      ? '0x'
      : '0x${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

  /// Recipient and amount as they will actually be signed, decoded from the
  /// transaction itself rather than from what the user typed.
  ({String recipient, BigInt amount})? _decodeTransfer() {
    final tx = widget.transaction;
    if (TransactionService().isEthToken(widget.token.address)) {
      if (tx.to == null) return null;
      return (
        recipient: tx.to!.with0x,
        amount: tx.value?.getInWei ?? BigInt.zero,
      );
    }
    final data = tx.data;
    if (data == null || data.length != 68) return null;
    if (bytesToHex(data.sublist(0, 4)) != _erc20TransferSelector) return null;
    return (
      recipient: '0x${bytesToHex(data.sublist(16, 36))}',
      amount: BigInt.parse(bytesToHex(data.sublist(36, 68)), radix: 16),
    );
  }

  // ---------------------------------------------------------------------------
  // Building blocks
  // ---------------------------------------------------------------------------

  Widget _sectionCard({
    required String title,
    String? caption,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: BrandColors.tan,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(caption,
                  style: const TextStyle(fontSize: 12, color: BrandColors.tan)),
            ],
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  /// One labelled value. [deviceHex] is the raw form the device prints, so
  /// the user can compare it character by character with the device screen.
  Widget _field(
    String label,
    String value, {
    String? deviceHex,
    bool mono = false,
    VoidCallback? onCopy,
  }) {
    final valueStyle = mono
        ? BrandColors.mono.copyWith(fontSize: 13, color: BrandColors.cream)
        : const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: BrandColors.cream);
    const labelStyle = TextStyle(fontSize: 13, color: BrandColors.tan);
    final hasHex = deviceHex != null && deviceHex != value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SelectableText.rich(
              TextSpan(children: [
                TextSpan(text: '$label: ', style: labelStyle),
                // When a device hex is shown it is the value to compare, so
                // it gets the emphasis and the readable value is muted.
                if (hasHex) ...[
                  TextSpan(text: value, style: labelStyle),
                  TextSpan(text: '  ($deviceHex)', style: valueStyle),
                ] else
                  TextSpan(text: value, style: valueStyle),
              ]),
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy, size: 16),
              color: BrandColors.tan,
              tooltip: 'Copy',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  Widget _statusHero() {
    final (Color color, IconData icon, String title, String subtitle) =
        switch (_status) {
      _SignStatus.waiting => (
          BrandColors.pending,
          Icons.usb,
          'Confirm on your device',
          'Check every value below against your Seed Silo screen, '
              'then approve or reject with the device buttons.',
        ),
      _SignStatus.sent => (
          BrandColors.verified,
          Icons.check,
          'Transaction sent',
          'Signed on your device and broadcast to ${widget.network.name}.',
        ),
      _SignStatus.rejected => (
          BrandColors.rust,
          Icons.block,
          'Rejected on device',
          'Nothing was signed or sent.',
        ),
      _SignStatus.failed => (
          BrandColors.rust,
          Icons.error_outline,
          'Transaction not sent',
          'Something went wrong. Your funds have not moved.',
        ),
    };

    final animate = _status == _SignStatus.waiting &&
        !MediaQuery.of(context).disableAnimations;

    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Column(
          key: ValueKey(_status),
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (animate)
                    FadeTransition(
                      opacity: Tween(begin: 0.8, end: 0.0).animate(_pulse),
                      child: ScaleTransition(
                        scale: Tween(begin: 0.7, end: 1.0).animate(_pulse),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 2),
                          ),
                        ),
                      ),
                    ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withAlpha(36),
                      border: Border.all(color: color.withAlpha(110)),
                    ),
                    child: Icon(icon, size: 30, color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: BrandColors.tan)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _errorBox(_error!),
            ],
            if (_status == _SignStatus.sent && _txHash != null) ...[
              const SizedBox(height: 16),
              _hashBox(_txHash!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandColors.rust.withAlpha(90)),
      ),
      child: SelectableText(
        message,
        style: const TextStyle(fontSize: 13, color: BrandColors.rust),
      ),
    );
  }

  Widget _hashBox(String hash) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: BrandColors.verified.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandColors.verified.withAlpha(80)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Transaction hash',
                    style: TextStyle(fontSize: 11, color: BrandColors.tan)),
                const SizedBox(height: 2),
                SelectableText(hash,
                    style: BrandColors.mono.copyWith(fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _copy(hash, 'Transaction hash'),
            icon: const Icon(Icons.copy, size: 18),
            color: BrandColors.verified,
            tooltip: 'Copy hash',
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(({String recipient, BigInt amount})? transfer) {
    final tx = widget.transaction;
    final maxNetworkFee = tx.maxGas != null && tx.maxFeePerGas != null
        ? BigInt.from(tx.maxGas!) * tx.maxFeePerGas!.getInWei
        : null;

    return _sectionCard(
      title: 'You are sending',
      children: [
        if (transfer != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: _decimal(transfer.amount, widget.token.decimals),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700),
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
          )
        else
          _errorBox('Could not decode the transfer from this transaction. '
              'Review the raw values below carefully, or reject it on the '
              'device.'),
        const Divider(height: 16),
        if (transfer != null)
          _field('To', transfer.recipient,
              mono: true,
              onCopy: () => _copy(transfer.recipient, 'Recipient address')),
        _field('From', widget.walletAddress,
            mono: true,
            onCopy: () => _copy(widget.walletAddress, 'Wallet address')),
        _field('Network', widget.network.name),
        if (maxNetworkFee != null)
          _field('Max network fee', '${_decimal(maxNetworkFee, 18)} ETH'),
      ],
    );
  }

  /// Fields in the same order and hex form as the device prints them.
  Widget _deviceCard(({String recipient, BigInt amount})? transfer) {
    final tx = widget.transaction;
    final chainId = widget.network.chainId;
    final isEth = TransactionService().isEthToken(widget.token.address);

    return _sectionCard(
      title: 'Verify on device',
      children: [
        _field('Chain ID', '$chainId', deviceHex: _hex(BigInt.from(chainId))),
        _field('Nonce', tx.nonce?.toString() ?? '—',
            deviceHex: tx.nonce == null ? null : _hex(BigInt.from(tx.nonce!))),
        _field('Max priority fee', _gwei(tx.maxPriorityFeePerGas),
            deviceHex: _hex(tx.maxPriorityFeePerGas?.getInWei)),
        _field('Max fee', _gwei(tx.maxFeePerGas),
            deviceHex: _hex(tx.maxFeePerGas?.getInWei)),
        _field(
            'Gas limit',
            tx.maxGas == null
                ? '—'
                : '${_decimal(BigInt.from(tx.maxGas!), 0)} units',
            deviceHex:
                tx.maxGas == null ? null : _hex(BigInt.from(tx.maxGas!))),
        _field(isEth ? 'To' : 'To (token contract)', tx.to?.with0x ?? '—',
            mono: true),
        _field(
            'Value', '${_decimal(tx.value?.getInWei ?? BigInt.zero, 18)} ETH',
            deviceHex: _hex(tx.value?.getInWei ?? BigInt.zero)),
        if (!isEth && transfer != null) ...[
          _field('Data', 'EIP-20 transfer (0x$_erc20TransferSelector)'),
          _field('Transfer to', transfer.recipient, mono: true),
          _field(
              'Transfer amount',
              '${_decimal(transfer.amount, widget.token.decimals)} '
                  '${widget.token.symbol}',
              deviceHex: _hex(transfer.amount)),
        ],
        _field('Raw data', _calldata(tx.data), mono: true),
      ],
    );
  }

  Widget _bottomActions() {
    final Widget child;
    switch (_status) {
      case _SignStatus.waiting:
        child = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: BrandColors.pending),
                ),
                const SizedBox(width: 10),
                Text(
                    _cancelling
                        ? 'Cancelling on device…'
                        : 'Waiting for device — keep it connected',
                    style: const TextStyle(
                        fontSize: 13, color: BrandColors.tan)),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: _cancelling ? null : _cancel,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          ],
        );
      case _SignStatus.sent:
        child = ElevatedButton(
          style:
              ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text('Done'),
        );
      case _SignStatus.rejected:
      case _SignStatus.failed:
        child = ElevatedButton.icon(
          style:
              ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Back to main screen'),
        );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transfer = _decodeTransfer();
    final waiting = _status == _SignStatus.waiting;

    return PopScope(
      // The device is still waiting for the user; leaving now would orphan
      // the pending signing request on the serial port, so a back gesture
      // cancels it on the device first and the screen pops afterwards.
      canPop: !waiting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sign Transaction'),
          leading: waiting
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Cancel and go back',
                  onPressed: _cancelling ? null : _cancel,
                )
              : null,
        ),
        bottomNavigationBar: _bottomActions(),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          children: [
            _statusHero(),
            const SizedBox(height: 24),
            _summaryCard(transfer),
            const SizedBox(height: 16),
            _deviceCard(transfer),
          ],
        ),
      ),
    );
  }
}
