import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/duration_format.dart';
import '../../application/player_notifier.dart';

class SeekBar extends ConsumerStatefulWidget {
  const SeekBar({super.key});

  @override
  ConsumerState<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<SeekBar> {
  /// Slider position (ms) while the user is dragging; null otherwise.
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = player.duration;
    final totalMs = duration?.inMilliseconds.toDouble() ?? 0;
    final seekable =
        player.hasTrack &&
        !player.isLoading &&
        player.error == null &&
        totalMs > 0;
    final shownMs = (_dragMs ?? position.inMilliseconds.toDouble()).clamp(
      0.0,
      totalMs > 0 ? totalMs : 1.0,
    );
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppColors.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: seekable ? shownMs : 0,
            max: totalMs > 0 ? totalMs : 1,
            onChanged: seekable ? (v) => setState(() => _dragMs = v) : null,
            onChangeEnd: seekable
                ? (v) {
                    setState(() => _dragMs = null);
                    ref
                        .read(playerProvider.notifier)
                        .seek(Duration(milliseconds: v.round()));
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(Duration(milliseconds: shownMs.round())),
                style: labelStyle,
              ),
              Text(formatDurationOrUnknown(duration), style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }
}
