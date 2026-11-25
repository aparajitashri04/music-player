import 'package:flutter/foundation.dart';

import 'eq_band_mapping.dart';

enum EqStatus {
  /// Waiting for the audio engine to expose its equalizer.
  initializing,
  ready,
  unsupported,
  error,
}

@immutable
class EqState {
  const EqState({
    this.status = EqStatus.initializing,
    this.gains = const {EqGroup.low: 0, EqGroup.mid: 0, EqGroup.high: 0},
    this.enabled = true,
    this.minDb = -maxUserGainDb,
    this.maxDb = maxUserGainDb,
    this.message,
  });

  final EqStatus status;
  final Map<EqGroup, double> gains;
  final bool enabled;
  final double minDb;
  final double maxDb;
  final String? message;

  bool get isReady => status == EqStatus.ready;
  bool get isFlat => gains.values.every((g) => g == 0);

  EqState copyWith({
    EqStatus? status,
    Map<EqGroup, double>? gains,
    bool? enabled,
    double? minDb,
    double? maxDb,
    String? Function()? message,
  }) {
    return EqState(
      status: status ?? this.status,
      gains: gains ?? this.gains,
      enabled: enabled ?? this.enabled,
      minDb: minDb ?? this.minDb,
      maxDb: maxDb ?? this.maxDb,
      message: message != null ? message() : this.message,
    );
  }
}
