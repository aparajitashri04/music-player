import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/track.dart';

abstract interface class MetadataReader {
  /// Returns whatever tags could be read. Never throws: an unreadable file
  /// yields empty metadata and the caller falls back to the file name.
  Future<TrackMetadata> read(String uri);
}

/// Reads tags through the Kotlin `MediaMetadataRetriever` bridge in
/// `MainActivity`.
class AndroidMetadataReader implements MetadataReader {
  static const _channel = MethodChannel('music_play/metadata');

  @override
  Future<TrackMetadata> read(String uri) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('read', {
        'uri': uri,
      });
      if (result == null) return const TrackMetadata();
      final durationMs = result['durationMs'] as int?;
      return TrackMetadata(
        title: result['title'] as String?,
        artist: result['artist'] as String?,
        album: result['album'] as String?,
        duration: durationMs == null
            ? null
            : Duration(milliseconds: durationMs),
      );
    } on PlatformException {
      return const TrackMetadata();
    } on MissingPluginException {
      return const TrackMetadata();
    }
  }
}

/// Used where no tag reader exists yet; tracks fall back to file-name titles.
class NoopMetadataReader implements MetadataReader {
  @override
  Future<TrackMetadata> read(String uri) async => const TrackMetadata();
}

MetadataReader createMetadataReader() =>
    Platform.isAndroid ? AndroidMetadataReader() : NoopMetadataReader();
