import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

import '../../library/domain/track.dart';
import '../domain/playback_engine.dart';

class JustAudioPlaybackEngine implements PlaybackEngine {
  JustAudioPlaybackEngine(this._player);

  final AudioPlayer _player;
  final _sourceLoaded = StreamController<void>.broadcast();

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<EnginePhase> get phaseStream =>
      _player.processingStateStream.map(_mapPhase).distinct();

  @override
  Stream<void> get sourceLoaded => _sourceLoaded.stream;

  @override
  Future<void> load(Track track) async {
    final uri = track.uri;
    if (uri != null) {
      final parsed = Uri.parse(uri);
      if (parsed.scheme == 'file' && !await File.fromUri(parsed).exists()) {
        throw const PlaybackLoadException(
          'This file is missing or can no longer be read.',
        );
      }
    }

    try {
      final source = track.assetPath != null
          ? AudioSource.asset(track.assetPath!)
          : AudioSource.uri(Uri.parse(uri!));
      await _player.setAudioSource(source);
      _sourceLoaded.add(null);
    } on PlayerInterruptedException {
      throw const PlaybackInterruptedException();
    } on PlayerException catch (e) {
      throw PlaybackLoadException(
        e.message ?? 'This audio file could not be played.',
      );
    } on Exception {
      throw const PlaybackLoadException('This audio file could not be played.');
    }
  }

  // just_audio's play() completes only when playback pauses or finishes, so it
  // is intentionally not awaited.
  @override
  void play() => unawaited(_player.play().catchError((Object _) {}));

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() async {
    await _sourceLoaded.close();
    await _player.dispose();
  }

  static EnginePhase _mapPhase(ProcessingState state) => switch (state) {
    ProcessingState.idle => EnginePhase.idle,
    ProcessingState.loading || ProcessingState.buffering => EnginePhase.loading,
    ProcessingState.ready => EnginePhase.ready,
    ProcessingState.completed => EnginePhase.completed,
  };
}
