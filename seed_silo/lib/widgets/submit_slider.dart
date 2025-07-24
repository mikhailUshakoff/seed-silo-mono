import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';

class SubmitSlider extends StatefulWidget {
  final Future<void> Function() onSubmit;
  final String label;

  const SubmitSlider({
    super.key,
    required this.onSubmit,
    this.label = 'Slide to Submit',
  });

  @override
  State<SubmitSlider> createState() => _SubmitSliderState();
}

class _SubmitSliderState extends State<SubmitSlider> {
  @override
  Widget build(BuildContext context) {
    return SlideAction(
      text: widget.label,
      outerColor: Theme.of(context).colorScheme.primary,
      innerColor: Theme.of(context).colorScheme.surface,
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
