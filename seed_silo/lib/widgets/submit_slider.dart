import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';

class SubmitSlider extends StatefulWidget {
  final Future<void> Function() onSubmit;
  final String label;
  final bool enabled;

  const SubmitSlider({
    super.key,
    required this.onSubmit,
    this.enabled = true,
    this.label = 'Slide to Submit',
  });

  @override
  State<SubmitSlider> createState() => _SubmitSliderState();
}

class _SubmitSliderState extends State<SubmitSlider> {
  @override
  Widget build(BuildContext context) {
    return SlideAction(
      text: widget.enabled ? widget.label : 'Loading data. Please wait...',
      enabled: widget.enabled,
      outerColor: Theme.of(context).colorScheme.primary,
      innerColor: widget.enabled ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.primary,
      textStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
      elevation: 0,
      animationDuration: const Duration(milliseconds: 300),
      submittedIcon: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 4, color: Theme.of(context).colorScheme.onPrimary,),
            ),
      onSubmit: () async {
        await widget.onSubmit();
      },
    );
  }
}
