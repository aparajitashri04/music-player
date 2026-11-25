import '../domain/equalizer_engine.dart';

/// Placeholder for platforms without an equalizer implementation. A future iOS
/// engine (AVAudioEngine + AVAudioUnitEQ) would replace this behind the same
/// [EqualizerEngine] interface.
class UnsupportedEqualizerEngine implements EqualizerEngine {
  const UnsupportedEqualizerEngine(this.unsupportedReason);

  @override
  final String unsupportedReason;

  @override
  bool get isSupported => false;

  @override
  Future<EqualizerDevice> initialize() =>
      throw EqualizerUnavailableException(unsupportedReason);

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<void> setBandGain(int bandIndex, double decibels) async {}
}
