import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FormattedAmountField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final int decimals;
  final String? Function(String?)? validator;

  const FormattedAmountField({
    super.key,
    required this.controller,
    required this.label,
    required this.decimals,
    this.validator,
  });

  @override
  State<FormattedAmountField> createState() => _FormattedAmountFieldState();
}

class _FormattedAmountFieldState extends State<FormattedAmountField> {
  bool _isEditing = false;
  int _inputLength = 0;
  double _convertedValue = 0;

  String get rawText => widget.controller.text.replaceAll(' ', '');

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (_isEditing) return;
    _isEditing = true;

    final oldText = widget.controller.text;
    final oldSelection = widget.controller.selection.baseOffset;

    final raw = oldText.replaceAll(' ', '');

    final match = RegExp(r'^(\d*)(\.?\d*)').firstMatch(raw);
    if (match == null) {
      _isEditing = false;
      return;
    }

    final integerPart = match.group(1) ?? '';
    final decimalPart = match.group(2) ?? '';

    final reversed = integerPart.split('').reversed.join();
    final spacedReversed = RegExp(r'.{1,3}')
        .allMatches(reversed)
        .map((m) => m.group(0))
        .join(' ');
    final formattedInteger = spacedReversed.split('').reversed.join();

    final formatted = '$formattedInteger$decimalPart';

    int numSpacesBefore = ' '.allMatches(oldText.substring(0, oldSelection)).length;
    int cursorPosRaw = oldSelection - numSpacesBefore;
    int newCursorPos = 0;
    int digitsSeen = 0;

    for (int i = 0; i < formatted.length && digitsSeen < cursorPosRaw; i++) {
      if (formatted[i] != ' ') {
        digitsSeen++;
      }
      newCursorPos++;
    }

    widget.controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    final digitsOnly = formatted.replaceAll(RegExp(r'[^0-9]'), '');
    _inputLength = digitsOnly.length;

    // Convert digitsOnly to number divided by 10^decimals
    if (digitsOnly.isEmpty) {
      _convertedValue = 0;
    } else {
      try {
        final rawInt = BigInt.parse(digitsOnly);
        final divisor = BigInt.from(10).pow(widget.decimals);
        final valueDouble = rawInt / divisor;
        _convertedValue = valueDouble.toDouble();
      } catch (_) {
        _convertedValue = 0;
      }
    }

    setState(() {});

    _isEditing = false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          decoration: InputDecoration(labelText: widget.label),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          validator: widget.validator,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Value: $_convertedValue'),
            const SizedBox(width: 16),
            Text('Input length: $_inputLength'),
          ],
        ),
      ],
    );
  }
}
