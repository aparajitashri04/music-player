import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/player/application/player_notifier.dart';
import '../../features/player/presentation/widgets/playback_controls.dart';
import 'album_art.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.current;
    if (track == null) return const SizedBox.shrink();

    final notifier = ref.read(playerProvider.notifier);
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final total = player.duration?.inMilliseconds ?? 0;
    final progress = total > 0
        ? (position.inMilliseconds / total).clamp(0.0, 1.0)
        : 0.0;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    AlbumArt(track: track, size: 44, radius: 10),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            player.error ?? track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: player.error != null
                                  ? AppColors.error
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PlaybackControls(
                      compact: true,
                      isPlaying: player.isPlaying && player.error == null,
                      isLoading: player.isLoading,
                      enabled: true,
                      onPrevious: notifier.previous,
                      onPlayPause: notifier.togglePlayPause,
                      onNext: notifier.next,
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: progress,
                minHeight: 2,
                color: AppColors.accent,
                backgroundColor: AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
