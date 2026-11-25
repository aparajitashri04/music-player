import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../domain/equalizer_engine.dart';

/// Drives `android.media.audiofx.Equalizer` through just_audio's
/// [AndroidEqualizer], which is attached to the player's audio session.
class AndroidEqualizerEngine implements EqualizerEngine {
  AndroidEqualizerEngine(this._equalizer);

  final AndroidEqualizer _equalizer;
  AndroidEqualizerParameters? _parameters;

  @override
  bool get isSupported => true;

  @override
  String get unsupportedReason => '';

  @override
  Future<EqualizerDevice> initialize() async {
    try {
      // Resolves only once the player has created its native session, i.e.
      // after the first source has loaded.
      final parameters = _parameters ??= await _equalizer.parameters.timeout(
        const Duration(seconds: 6),
      );
      if (parameters.bands.isEmpty) {
        throw const EqualizerUnavailableException(
          'This device reports no equalizer bands.',
        );
      }
      await _equalizer.setEnabled(true);
      return EqualizerDevice(
        minDb: parameters.minDecibels,
        maxDb: parameters.maxDecibels,
        bands: [
          for (final band in parameters.bands)
            DeviceBand(index: band.index, centerHz: band.centerFrequency),
        ],
      );
    } on TimeoutException {
      throw const EqualizerUnavailableException(
        'The audio engine is not ready yet. Start playback to activate the equalizer.',
      );
    } on EqualizerUnavailableException {
      rethrow;
    } catch (_) {
      throw const EqualizerUnavailableException(
        'The device audio effect could not be created.',
      );
    }
  }

  @override
  Future<void> setEnabled(bool enabled) => _equalizer.setEnabled(enabled);

  @override
  Future<void> setBandGain(int bandIndex, double decibels) async {
    final bands = _parameters?.bands;
    if (bands == null || bandIndex < 0 || bandIndex >= bands.length) {
      throw const EqualizerUnavailableException(
        'Equalizer is not initialised.',
      );
    }
    await bands[bandIndex].setGain(decibels);
  }
}
