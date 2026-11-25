import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

String formatDb(double db) {
  final rounded = (db * 10).round() / 10;
  if (rounded == 0) return '0 dB';
  final sign = rounded > 0 ? '+' : '−';
  return '$sign${rounded.abs().toStringAsFixed(1)} dB';
}

class EqSlider extends StatelessWidget {
  const EqSlider({
    super.key,
    required this.label,
    required this.rangeLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
    this.height = 240,
  });

  final String label;
  final String rangeLabel;
  final double value;
  final double min;
  final double max;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divisions = ((max - min) * 2).round().clamp(1, 1000);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatDb(value),
          style: theme.textTheme.titleMedium?.copyWith(
            color: enabled && value != 0
                ? AppColors.accent
                : AppColors.textSecondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: height,
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              key: ValueKey('eq-slider-$label'),
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              semanticFormatterCallback: formatDb,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(label, style: theme.textTheme.titleMedium),
        Text(
          rangeLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
