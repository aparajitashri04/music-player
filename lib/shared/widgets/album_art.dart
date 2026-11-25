import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/library/domain/track.dart';

/// Flat artwork: a solid muted-pink swatch picked deterministically from the
/// track id, with a music-note icon.
class AlbumArt extends StatelessWidget {
  const AlbumArt({
    super.key,
    required this.track,
    this.size,
    this.radius = AppRadii.card,
  });

  final Track? track;
  final double? size;
  final double radius;

  /// Stable across runs (unlike [Object.hashCode] on strings).
  static Color colorFor(String? id) {
    if (id == null) return AppColors.card;
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return AppColors.artPalette[hash % AppColors.artPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final track = this.track;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorFor(track?.id),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Icon(
              Icons.music_note_rounded,
              color: track == null
                  ? AppColors.textSecondary
                  : AppColors.onAccent.withValues(alpha: 0.7),
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
