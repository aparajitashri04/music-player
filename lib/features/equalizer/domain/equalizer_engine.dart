import 'package:flutter/foundation.dart';

@immutable
class DeviceBand {
  const DeviceBand({required this.index, required this.centerHz});

  final int index;
  final double centerHz;
}

@immutable
class EqualizerDevice {
  const EqualizerDevice({
    required this.bands,
    required this.minDb,
    required this.maxDb,
  });

  final List<DeviceBand> bands;
  final double minDb;
  final double maxDb;
}

class EqualizerUnavailableException implements Exception {
  const EqualizerUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Audio equalization, kept separate from playback so each platform can plug in
/// its own DSP (Android `android.media.audiofx.Equalizer` today; AVAudioUnitEQ
/// on iOS later).
abstract interface class EqualizerEngine {
  bool get isSupported;

  /// Shown to the user when [isSupported] is false.
  String get unsupportedReason;

  /// Resolves the device's bands and enables the effect. Throws
  /// [EqualizerUnavailableException] if the platform cannot provide one.
  Future<EqualizerDevice> initialize();

  Future<void> setEnabled(bool enabled);

  Future<void> setBandGain(int bandIndex, double decibels);
}
