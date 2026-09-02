import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';

class SubmitSlider extends StatefulWidget {
  final Future<void> Function() onSubmit;
  final String label;
  final bool enabled;

  /// Keeps the spinner the slider shows once it is slid, driven by the parent
  /// instead of by the gesture.
  final bool loading;

  const SubmitSlider({
    super.key,
    required this.onSubmit,
    this.enabled = true,
    this.loading = false,
    this.label = 'Slide to Submit',
  });

  @override
  State<SubmitSlider> createState() => _SubmitSliderState();
}

class _SubmitSliderState extends State<SubmitSlider> {
  static const double _height = 70;
  static const double _borderRadius = 52;
  static const Duration _animationDuration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Kept in the tree while loading so the package's own animation
        // controllers stay alive if a real slide is still in flight.
        Opacity(
          opacity: widget.loading ? 0 : 1,
          child: IgnorePointer(
            ignoring: widget.loading,
            child: SlideAction(
              height: _height,
              borderRadius: _borderRadius,
              text:
                  widget.enabled ? widget.label : 'Loading data. Please wait...',
              enabled: widget.enabled,
              outerColor: colorScheme.primary,
              innerColor:
                  widget.enabled ? colorScheme.surface : colorScheme.primary,
              textStyle: TextStyle(color: colorScheme.onPrimary),
              elevation: 0,
              animationDuration: _animationDuration,
              submittedIcon: _spinner(colorScheme),
              onSubmit: () async {
                await widget.onSubmit();
              },
            ),
          ),
        ),
        if (widget.loading)
          SizedBox(
            height: _height,
            width: _height,
            child: Material(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(_borderRadius),
              child: Center(child: _spinner(colorScheme)),
            ),
          ),
      ],
    );
  }

  Widget _spinner(ColorScheme colorScheme) => SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 4,
          color: colorScheme.onPrimary,
        ),
      );
}
