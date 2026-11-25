import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/panel.dart';
import '../application/equalizer_notifier.dart';
import '../domain/eq_band_mapping.dart';
import '../domain/eq_state.dart';
import 'widgets/eq_slider.dart';

const _rangeLabels = {
  EqGroup.low: 'Below 250 Hz',
  EqGroup.mid: '250 Hz – 4 kHz',
  EqGroup.high: 'Above 4 kHz',
};

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(equalizerProvider);
    final notifier = ref.read(equalizerProvider.notifier);
    final theme = Theme.of(context);
    final active = eq.isReady && eq.enabled;

    if (eq.status == EqStatus.unsupported) {
      return _UnsupportedEqualizer(detail: eq.message);
    }

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Equalizer',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Three bands, ±${maxUserGainDb.toInt()} dB',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: eq.enabled && eq.isReady,
                    onChanged: eq.isReady ? notifier.setEnabled : null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _StatusBanner(eq: eq, onRetry: notifier.retry),
              Panel(
                child: Column(
                  children: [
                    SizedBox(
                      height: 72,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _ResponseCurvePainter(
                          gains: eq.gains,
                          min: eq.minDb,
                          max: eq.maxDb,
                          active: active,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final group in EqGroup.values)
                          EqSlider(
                            label: group.label,
                            rangeLabel: _rangeLabels[group]!,
                            value: eq.gains[group] ?? 0,
                            min: eq.minDb,
                            max: eq.maxDb,
                            enabled: active,
                            onChanged: (v) => notifier.setGain(group, v),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: eq.isReady && !eq.isFlat ? notifier.reset : null,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnsupportedEqualizer extends StatelessWidget {
  const _UnsupportedEqualizer({this.detail});

  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Equalizer', style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              Panel(
                child: Column(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      size: 36,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Equalizer is available on Android only.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        detail!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.eq, required this.onRetry});

  final EqState eq;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, Color color, String text) = switch (eq.status) {
      EqStatus.ready => (
        Icons.check_circle_outline_rounded,
        AppColors.accent,
        '',
      ),
      EqStatus.initializing => (
        Icons.hourglass_empty_rounded,
        AppColors.textSecondary,
        'Starting the audio engine…',
      ),
      EqStatus.unsupported => (
        Icons.info_outline_rounded,
        AppColors.textSecondary,
        eq.message ?? 'The equalizer is not available on this platform.',
      ),
      EqStatus.error => (
        Icons.error_outline_rounded,
        AppColors.error,
        eq.message ?? 'The equalizer is unavailable.',
      ),
    };
    if (eq.status == EqStatus.ready) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (eq.status == EqStatus.error)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ResponseCurvePainter extends CustomPainter {
  _ResponseCurvePainter({
    required this.gains,
    required this.min,
    required this.max,
    required this.active,
  });

  final Map<EqGroup, double> gains;
  final double min;
  final double max;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 1,
    );

    double y(double db) {
      final span = (max - min).abs() < 1e-6 ? 1 : max - min;
      return size.height - ((db - min) / span) * size.height;
    }

    final xs = [size.width * 1 / 6, size.width * 3 / 6, size.width * 5 / 6];
    final ys = [for (final g in EqGroup.values) y(gains[g] ?? 0)];
    final path = Path()..moveTo(0, ys.first);
    path.lineTo(xs[0] / 2, ys[0]);
    for (var i = 0; i < 2; i++) {
      final midX = (xs[i] + xs[i + 1]) / 2;
      path.cubicTo(midX, ys[i], midX, ys[i + 1], xs[i + 1], ys[i + 1]);
    }
    path.lineTo(size.width, ys.last);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = active ? AppColors.accent : AppColors.textSecondary,
    );
  }

  @override
  bool shouldRepaint(_ResponseCurvePainter old) =>
      old.gains != gains ||
      old.min != min ||
      old.max != max ||
      old.active != active;
}
