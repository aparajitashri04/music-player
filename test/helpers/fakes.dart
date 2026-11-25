import 'dart:async';

import 'package:music_play/features/equalizer/domain/equalizer_engine.dart';
import 'package:music_play/features/library/data/library_store.dart';
import 'package:music_play/features/library/domain/track.dart';
import 'package:music_play/features/player/domain/playback_engine.dart';

class FakePlaybackEngine implements PlaybackEngine {
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _phase = StreamController<EnginePhase>.broadcast();
  final _sourceLoaded = StreamController<void>.broadcast();

  /// Ids of tracks whose [load] calls completed, in order.
  final List<String> loaded = [];
  final List<Duration> seeks = [];
  final Map<String, Completer<void>> gates = {};
  final Set<String> failing = {};
  bool playing = false;
  int _loadCalls = 0;

  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<Duration?> get durationStream => _duration.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<EnginePhase> get phaseStream => _phase.stream;
  @override
  Stream<void> get sourceLoaded => _sourceLoaded.stream;

  @override
  Future<void> load(Track track) async {
    final call = ++_loadCalls;
    final gate = gates[track.id];
    if (gate != null) await gate.future;
    if (call != _loadCalls) throw const PlaybackInterruptedException();
    if (failing.contains(track.id)) {
      throw const PlaybackLoadException('This file is missing.');
    }
    loaded.add(track.id);
    _duration.add(track.duration);
    _phase.add(EnginePhase.ready);
    _sourceLoaded.add(null);
  }

  @override
  void play() {
    playing = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    playing = false;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  void emitPosition(Duration position) => _position.add(position);
  void emitCompleted() => _phase.add(EnginePhase.completed);

  @override
  Future<void> dispose() async {
    for (final controller in [
      _position,
      _duration,
      _playing,
      _phase,
      _sourceLoaded,
    ]) {
      await controller.close();
    }
  }
}

class FakeEqualizerEngine implements EqualizerEngine {
  FakeEqualizerEngine({
    this.supported = true,
    this.minDb = -15,
    this.maxDb = 15,
    this.centers = const [60, 230, 910, 3600, 14000],
  });

  final bool supported;
  final double minDb;
  final double maxDb;
  final List<double> centers;

  /// Gain last written to each device band index.
  final Map<int, double> gains = {};
  bool enabled = false;
  bool failInitialize = false;
  bool failSetGain = false;

  @override
  bool get isSupported => supported;

  @override
  String get unsupportedReason => 'Not available in tests.';

  @override
  Future<EqualizerDevice> initialize() async {
    if (failInitialize) {
      throw const EqualizerUnavailableException('No equalizer on this device.');
    }
    return EqualizerDevice(
      minDb: minDb,
      maxDb: maxDb,
      bands: [
        for (var i = 0; i < centers.length; i++)
          DeviceBand(index: i, centerHz: centers[i]),
      ],
    );
  }

  @override
  Future<void> setEnabled(bool value) async => enabled = value;

  @override
  Future<void> setBandGain(int bandIndex, double decibels) async {
    if (failSetGain) throw StateError('rejected');
    gains[bandIndex] = decibels;
  }
}

/// Keeps the library in memory so tests never touch the real file system.
class MemoryLibraryStore implements LibraryStore {
  MemoryLibraryStore([this.data = const PersistedLibrary()]);

  PersistedLibrary data;
  int saves = 0;

  @override
  Future<PersistedLibrary> load() async => data;

  @override
  Future<void> save(PersistedLibrary library) async {
    saves++;
    data = library;
  }
}
