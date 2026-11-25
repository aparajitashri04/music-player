import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../shared/widgets/album_art.dart';
import '../../domain/track.dart';

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    this.onMove,
    this.onRemove,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
  });

  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  /// When either action is given, the tile shows an overflow menu.
  final VoidCallback? onMove;
  final VoidCallback? onRemove;

  /// Long press starts multi-select; while [selectionMode] is on, taps toggle
  /// [selected] instead of playing.
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.22)
          : isCurrent
          ? AppColors.accent.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.control),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          child: Row(
            children: [
              if (selectionMode) ...[
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              AlbumArt(track: track, size: 52, radius: 12),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isCurrent ? AppColors.accent : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (isCurrent) ...[
                NowPlayingBars(animating: isPlaying),
                const SizedBox(width: AppSpacing.md),
              ],
              Text(
                formatDurationOrUnknown(track.duration),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (!selectionMode && (onMove != null || onRemove != null))
                PopupMenuButton<VoidCallback>(
                  tooltip: 'Track options',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  color: AppColors.card,
                  onSelected: (action) => action(),
                  itemBuilder: (_) => [
                    if (onMove != null)
                      PopupMenuItem(
                        value: onMove,
                        child: const Text('Move to folder'),
                      ),
                    if (onRemove != null)
                      PopupMenuItem(
                        value: onRemove,
                        child: const Text('Remove from library'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NowPlayingBars extends StatefulWidget {
  const NowPlayingBars({super.key, required this.animating});

  final bool animating;

  @override
  State<NowPlayingBars> createState() => _NowPlayingBarsState();
}

class _NowPlayingBarsState extends State<NowPlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animating) _controller.repeat();
  }

  @override
  void didUpdateWidget(NowPlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animating && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 4,
                height: widget.animating
                    ? 4 +
                          14 *
                              (0.5 +
                                  0.5 *
                                      math.sin(
                                        _controller.value * 2 * math.pi +
                                            i * 1.7,
                                      ))
                    : 6.0,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
