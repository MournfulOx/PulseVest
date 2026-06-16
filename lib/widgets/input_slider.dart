import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InputSlider extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String? prefix;
  final String? suffix;
  final bool isInt;
  final ValueChanged<double> onChanged;

  const InputSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    this.prefix,
    this.suffix,
    this.isInt = false,
    required this.onChanged,
  });

  @override
  State<InputSlider> createState() => _InputSliderState();
}

class _InputSliderState extends State<InputSlider> {
  bool _active = false;
  double? _lastSnap;

  String get _valueLabel {
    final val = widget.isInt ? widget.value.round() : widget.value;
    final formatted = widget.isInt
        ? val.toString()
        : widget.value >= 1000
            ? widget.value.toStringAsFixed(0)
            : widget.value.toStringAsFixed(1);
    return '${widget.prefix ?? ''}$formatted${widget.suffix ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 13, color: Colors.white.withOpacity(0.7))),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.4),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: anim,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                ),
                child: Text(
                  _valueLabel,
                  key: ValueKey(_valueLabel),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary),
                ),
              ),
            ],
          ),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            tween: Tween(end: _active ? 8.0 : 6.0),
            builder: (_, radius, __) => SliderTheme(
              data: SliderThemeData(
                activeTrackColor: scheme.primary,
                inactiveTrackColor: scheme.primary.withOpacity(0.15),
                thumbColor: scheme.primary,
                overlayColor: scheme.primary.withOpacity(0.15),
                trackHeight: 3,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: radius),
              ),
              child: Slider(
                value: widget.value.clamp(widget.min, widget.max),
                min: widget.min,
                max: widget.max,
                divisions: widget.divisions,
                onChangeStart: (_) => setState(() => _active = true),
                onChangeEnd: (_) => setState(() => _active = false),
                onChanged: (v) {
                  final step = (widget.max - widget.min) / widget.divisions;
                  final snap = (v / step).round() * step;
                  if (_lastSnap != snap) {
                    _lastSnap = snap;
                    HapticFeedback.selectionClick();
                  }
                  widget.onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
