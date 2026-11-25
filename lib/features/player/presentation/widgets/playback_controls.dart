import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.enabled,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    this.compact = false,
  });

  final bool isPlaying;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final skipSize = compact ? 28.0 : 36.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous',
          iconSize: skipSize,
          onPressed: enabled ? onPrevious : null,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
        PlayPauseButton(
          isPlaying: isPlaying,
          isLoading: isLoading,
          onPressed: onPlayPause,
          size: compact ? 48 : 76,
        ),
        SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
        IconButton(
          tooltip: 'Next',
          iconSize: skipSize,
          onPressed: enabled ? onNext : null,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}

class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.onPressed,
    this.size = 76,
  });

  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isPlaying ? 'Pause' : 'Play',
      child: Material(
        color: AppColors.accent,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: isLoading
                  ? Center(
                      key: const ValueKey('loading'),
                      child: SizedBox(
                        width: size * 0.34,
                        height: size * 0.34,
                        child: const CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.onAccent,
                        ),
                      ),
                    )
                  : Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      key: ValueKey(isPlaying),
                      size: size * 0.52,
                      color: AppColors.onAccent,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
