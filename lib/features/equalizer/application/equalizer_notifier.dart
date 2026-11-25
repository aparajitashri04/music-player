import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/audio_backend.dart';
import '../domain/eq_band_mapping.dart';
import '../domain/eq_state.dart';
import '../domain/equalizer_engine.dart';

class EqualizerNotifier extends Notifier<EqState> {
  late final EqualizerEngine _engine = ref.read(equalizerEngineProvider);
  Map<EqGroup, List<int>> _groups = const {};
  bool _initializing = false;
  StreamSubscription<void>? _sourceSubscription;

  @override
  EqState build() {
    ref.onDispose(() => _sourceSubscription?.cancel());

    if (!_engine.isSupported) {
      return EqState(
        status: EqStatus.unsupported,
        message: _engine.unsupportedReason,
      );
    }

    // Gains are re-applied after every track load so the audio can never
    // drift from what the sliders show.
    _sourceSubscription = ref
        .read(playbackEngineProvider)
        .sourceLoaded
        .listen((_) => _onSourceLoaded());
    scheduleMicrotask(_initialize);
    return const EqState();
  }

  Future<void> retry() => _initialize();

  Future<void> setGain(EqGroup group, double decibels) async {
    if (!state.isReady) return;
    final gain = clampGain(
      decibels,
      deviceMinDb: state.minDb,
      deviceMaxDb: state.maxDb,
    );
    state = state.copyWith(gains: {...state.gains, group: gain});
    await _applyGroup(group);
  }

  Future<void> reset() async {
    if (!state.isReady) return;
    state = state.copyWith(gains: {for (final g in EqGroup.values) g: 0.0});
    await _applyAll();
  }

  Future<void> setEnabled(bool enabled) async {
    if (!state.isReady) return;
    state = state.copyWith(enabled: enabled);
    try {
      await _engine.setEnabled(enabled);
    } on Object {
      state = state.copyWith(
        status: EqStatus.error,
        message: () => 'The equalizer could not be switched.',
      );
    }
  }

  Future<void> _initialize() async {
    if (_initializing) return;
    _initializing = true;
    try {
      final device = await _engine.initialize();
      _groups = mapBandsToGroups(device.bands);
      state = state.copyWith(
        status: EqStatus.ready,
        minDb: device.minDb < -maxUserGainDb ? -maxUserGainDb : device.minDb,
        maxDb: device.maxDb > maxUserGainDb ? maxUserGainDb : device.maxDb,
        message: () => null,
      );
      await _engine.setEnabled(state.enabled);
      await _applyAll();
    } on EqualizerUnavailableException catch (e) {
      state = state.copyWith(status: EqStatus.error, message: () => e.message);
    } on Object {
      // Unexpected platform failure: never stay stuck in `initializing`.
      state = state.copyWith(
        status: EqStatus.error,
        message: () => 'The device equalizer could not be started.',
      );
    } finally {
      _initializing = false;
    }
  }

  Future<void> _onSourceLoaded() async {
    if (state.status == EqStatus.error ||
        state.status == EqStatus.initializing) {
      await _initialize();
    } else if (state.isReady) {
      try {
        await _engine.setEnabled(state.enabled);
      } on Object {
        state = state.copyWith(
          status: EqStatus.error,
          message: () => 'The equalizer could not be switched.',
        );
        return;
      }
      await _applyAll();
    }
  }

  Future<void> _applyAll() async {
    for (final group in EqGroup.values) {
      await _applyGroup(group);
    }
  }

  Future<void> _applyGroup(EqGroup group) async {
    final gain = state.gains[group] ?? 0;
    try {
      for (final band in _groups[group] ?? const <int>[]) {
        await _engine.setBandGain(band, gain);
      }
    } on Object {
      state = state.copyWith(
        status: EqStatus.error,
        message: () => 'The device rejected an equalizer change.',
      );
    }
  }
}

final equalizerProvider = NotifierProvider<EqualizerNotifier, EqState>(
  EqualizerNotifier.new,
);
