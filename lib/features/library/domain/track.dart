import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

const String unknownArtist = 'Unknown artist';

/// Tags read from an audio file. Every field is optional because files in the
/// wild frequently lack tags.
@immutable
class TrackMetadata {
  const TrackMetadata({this.title, this.artist, this.album, this.duration});

  final String? title;
  final String? artist;
  final String? album;
  final Duration? duration;
}

/// A playable item. Exactly one of [assetPath] (bundled) or [uri] (imported
/// from the device) identifies the audio source.
@immutable
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.duration,
    this.assetPath,
    this.uri,
  }) : assert(
         (assetPath == null) != (uri == null),
         'A track needs exactly one of assetPath or uri',
       );

  /// Builds a track for an imported file, falling back to the file name for
  /// the title and [unknownArtist] when tags are missing or blank.
  factory Track.fromImport({
    required String uri,
    required String fileName,
    TrackMetadata? metadata,
  }) {
    String? clean(String? value) {
      final trimmed = value?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }

    final duration = metadata?.duration;
    return Track(
      id: 'file:$uri',
      title: clean(metadata?.title) ?? titleFromFileName(fileName),
      artist: clean(metadata?.artist) ?? unknownArtist,
      album: clean(metadata?.album),
      duration: (duration == null || duration <= Duration.zero)
          ? null
          : duration,
      uri: uri,
    );
  }

  final String id;
  final String title;
  final String artist;
  final String? album;
  final Duration? duration;
  final String? assetPath;
  final String? uri;

  bool get isBundled => assetPath != null;

  static String titleFromFileName(String fileName) {
    final base = p.basenameWithoutExtension(fileName).replaceAll('_', ' ');
    final trimmed = base.trim();
    return trimmed.isEmpty ? 'Untitled' : trimmed;
  }

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
