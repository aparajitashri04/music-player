import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/album_art.dart';
import '../../../shared/widgets/panel.dart';
import '../../library/application/library_notifier.dart';
import '../../library/presentation/widgets/track_tile.dart';
import '../application/player_notifier.dart';
import 'widgets/playback_controls.dart';
import 'widgets/seek_bar.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          return wide ? const _WideLayout() : const _CompactLayout();
        },
      ),
    );
  }
}

class _CompactLayout extends ConsumerWidget {
  const _CompactLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final artSize = (constraints.maxWidth - AppSpacing.lg * 2).clamp(
          160.0,
          constraints.maxHeight * 0.42,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - AppSpacing.lg * 2,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Artwork(size: artSize),
                const SizedBox(height: AppSpacing.xl),
                const _TrackHeader(alignment: CrossAxisAlignment.start),
                const SizedBox(height: AppSpacing.md),
                const SeekBar(),
                const SizedBox(height: AppSpacing.md),
                const _Controls(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WideLayout extends ConsumerWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(libraryProvider).tracks;
    final player = ref.watch(playerProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _Artwork(size: null),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _TrackHeader(alignment: CrossAxisAlignment.start),
                    const SizedBox(height: AppSpacing.sm),
                    const SeekBar(),
                    const SizedBox(height: AppSpacing.sm),
                    const _Controls(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            flex: 4,
            child: Panel(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text('Up next', style: theme.textTheme.titleLarge),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final track in tracks)
                          TrackTile(
                            track: track,
                            isCurrent: player.current == track,
                            isPlaying:
                                player.current == track && player.isPlaying,
                            onTap: () => ref
                                .read(playerProvider.notifier)
                                .selectTrack(track),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Artwork extends ConsumerWidget {
  const _Artwork({required this.size});

  final double? size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    return AnimatedScale(
      scale: player.isPlaying ? 1 : 0.94,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      child: AlbumArt(track: player.current, size: size, radius: 28),
    );
  }
}

class _TrackHeader extends ConsumerWidget {
  const _TrackHeader({required this.alignment});

  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final theme = Theme.of(context);
    final track = player.current;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Text(
            track?.title ?? 'Nothing playing',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            track?.artist ?? 'Pick a track from your library',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (player.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadii.control),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      player.error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    return PlaybackControls(
      isPlaying: player.isPlaying && player.error == null,
      isLoading: player.isLoading,
      enabled: player.hasTrack,
      onPrevious: notifier.previous,
      onPlayPause: notifier.togglePlayPause,
      onNext: notifier.next,
    );
  }
}
