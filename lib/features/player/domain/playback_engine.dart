import '../../library/domain/track.dart';

enum EnginePhase { idle, loading, ready, completed }

/// The track could not be opened (missing, unreadable or unsupported file).
class PlaybackLoadException implements Exception {
  const PlaybackLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A newer [PlaybackEngine.load] call superseded this one. Not an error.
class PlaybackInterruptedException implements Exception {
  const PlaybackInterruptedException();
}

/// Plays one source at a time. Queue and track-order logic live above this
/// interface; equalizing is a separate interface (see `EqualizerEngine`).
abstract interface class PlaybackEngine {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;
  Stream<EnginePhase> get phaseStream;

  /// Fires after every successful [load].
  Stream<void> get sourceLoaded;

  /// Throws [PlaybackLoadException] or [PlaybackInterruptedException].
  Future<void> load(Track track);

  void play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}
