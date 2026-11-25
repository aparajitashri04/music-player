import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/audio_backend.dart';
import '../../library/application/library_notifier.dart';
import '../../library/domain/track.dart';
import '../domain/playback_engine.dart';

@immutable
class PlayerState {
  const PlayerState({
    this.current,
    this.isPlaying = false,
    this.isLoading = false,
    this.duration,
    this.error,
  });

  final Track? current;
  final bool isPlaying;
  final bool isLoading;
  final Duration? duration;
  final String? error;

  bool get hasTrack => current != null;

  PlayerState copyWith({
    Track? current,
    bool? isPlaying,
    bool? isLoading,
    Duration? Function()? duration,
    String? Function()? error,
  }) {
    return PlayerState(
      current: current ?? this.current,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      duration: duration != null ? duration() : this.duration,
      error: error != null ? error() : this.error,
    );
  }
}

/// Restart the track instead of going back when more than this has played.
const Duration previousRestartThreshold = Duration(seconds: 3);

class PlayerNotifier extends Notifier<PlayerState> {
  late final PlaybackEngine _engine = ref.read(playbackEngineProvider);

  /// Incremented for every load request; a load whose token is stale was
  /// superseded by a newer selection and must not touch state.
  int _loadToken = 0;
  Duration _position = Duration.zero;
  EnginePhase _phase = EnginePhase.idle;

  @override
  PlayerState build() {
    final subscriptions = [
      _engine.playingStream.listen(
        (playing) => state = state.copyWith(isPlaying: playing),
      ),
      _engine.durationStream.listen((duration) {
        if (duration != null) state = state.copyWith(duration: () => duration);
      }),
      _engine.positionStream.listen((position) => _position = position),
      _engine.phaseStream.listen((phase) {
        _phase = phase;
        if (phase == EnginePhase.completed) _onCompleted();
      }),
    ];
    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });

    // If the playing track is removed from the library, move to its neighbour.
    ref.listen(
      libraryProvider.select((s) => s.tracks),
      (previous, next) => _onQueueChanged(previous ?? const [], next),
    );

    // Load the first track paused so the player (and the native equalizer)
    // is ready before the user presses play.
    scheduleMicrotask(() {
      final tracks = ref.read(libraryProvider).tracks;
      if (tracks.isNotEmpty && state.current == null) {
        _start(tracks.first, autoPlay: false);
      }
    });
    return const PlayerState();
  }

  List<Track> get _queue => ref.read(libraryProvider).tracks;

  int get _currentIndex {
    final current = state.current;
    return current == null ? -1 : _queue.indexOf(current);
  }

  Future<void> selectTrack(Track track) => _start(track, autoPlay: true);

  Future<void> togglePlayPause() async {
    if (state.current == null) {
      final tracks = _queue;
      if (tracks.isNotEmpty) await _start(tracks.first, autoPlay: true);
      return;
    }
    if (state.isLoading) return;
    if (state.error != null) {
      await _start(state.current!, autoPlay: true);
      return;
    }
    if (state.isPlaying) {
      await _engine.pause();
      return;
    }
    if (_phase == EnginePhase.completed) await _engine.seek(Duration.zero);
    _engine.play();
  }

  Future<void> next() async {
    final tracks = _queue;
    if (tracks.isEmpty || state.current == null) return;
    final index = _currentIndex;
    final target = tracks[(index + 1) % tracks.length];
    if (target == state.current) {
      await _restartCurrent();
      return;
    }
    await _start(target, autoPlay: true);
  }

  Future<void> previous() async {
    final tracks = _queue;
    if (tracks.isEmpty || state.current == null) return;
    final index = _currentIndex;
    if (_position > previousRestartThreshold || index <= 0) {
      await _restartCurrent();
      return;
    }
    await _start(tracks[index - 1], autoPlay: true);
  }

  Future<void> seek(Duration position) async {
    if (!state.hasTrack || state.isLoading || state.error != null) return;
    final limit = state.duration;
    var target = position < Duration.zero ? Duration.zero : position;
    if (limit != null && target > limit) target = limit;
    await _engine.seek(target);
  }

  Future<void> _restartCurrent() async {
    if (state.error != null) {
      await _start(state.current!, autoPlay: true);
      return;
    }
    await _engine.seek(Duration.zero);
    _engine.play();
  }

  Future<void> _start(Track track, {required bool autoPlay}) async {
    final token = ++_loadToken;
    state = state.copyWith(
      current: track,
      isLoading: true,
      duration: () => track.duration,
      error: () => null,
    );
    try {
      await _engine.load(track);
      if (token != _loadToken) return;
      state = state.copyWith(isLoading: false);
      if (autoPlay) _engine.play();
    } on PlaybackInterruptedException {
      return;
    } on PlaybackLoadException catch (e) {
      if (token != _loadToken) return;
      await _engine.pause();
      state = state.copyWith(isLoading: false, error: () => e.message);
    }
  }

  void _onQueueChanged(List<Track> previous, List<Track> next) {
    final current = state.current;
    if (current == null || next.contains(current)) return;
    final wasPlaying = state.isPlaying;
    if (next.isEmpty) {
      _loadToken++; // drop any load still in flight
      unawaited(_engine.pause());
      state = const PlayerState();
      return;
    }
    final removedAt = previous.indexOf(current);
    final target =
        next[(removedAt < 0 ? 0 : removedAt).clamp(0, next.length - 1)];
    unawaited(_start(target, autoPlay: wasPlaying));
  }

  Future<void> _onCompleted() async {
    if (state.isLoading) return;
    final tracks = _queue;
    final index = _currentIndex;
    if (index >= 0 && index < tracks.length - 1) {
      await _start(tracks[index + 1], autoPlay: true);
    } else {
      await _engine.pause();
      await _engine.seek(Duration.zero);
    }
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

final positionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(playbackEngineProvider).positionStream,
);
