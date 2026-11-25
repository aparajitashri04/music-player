import 'dart:math' as math;

import 'equalizer_engine.dart';

enum EqGroup {
  low('Low', 100),
  mid('Mid', 1000),
  high('High', 8000);

  const EqGroup(this.label, this.targetHz);

  final String label;

  /// Used only to pick a fallback band when no device band falls in range.
  final double targetHz;
}

const double lowMidCrossoverHz = 250;
const double midHighCrossoverHz = 4000;

/// User-facing gain range, further limited by what the device reports.
const double maxUserGainDb = 12;

EqGroup groupForFrequency(double hz) {
  if (hz <= lowMidCrossoverHz) return EqGroup.low;
  if (hz <= midHighCrossoverHz) return EqGroup.mid;
  return EqGroup.high;
}

/// Assigns every device band to the Low/Mid/High slider covering its centre
/// frequency, so 5-band and 10-band hardware both work. A slider whose range
/// holds no band borrows the band nearest to its target (on a log scale).
Map<EqGroup, List<int>> mapBandsToGroups(List<DeviceBand> bands) {
  final groups = {for (final g in EqGroup.values) g: <int>[]};
  for (final band in bands) {
    groups[groupForFrequency(band.centerHz)]!.add(band.index);
  }
  if (bands.isEmpty) return groups;
  for (final group in EqGroup.values) {
    if (groups[group]!.isNotEmpty) continue;
    final nearest = bands.reduce(
      (a, b) =>
          _logDistance(a.centerHz, group.targetHz) <=
              _logDistance(b.centerHz, group.targetHz)
          ? a
          : b,
    );
    groups[group]!.add(nearest.index);
  }
  return groups;
}

double _logDistance(double a, double b) => (math.log(a) - math.log(b)).abs();

/// Clamps to ±12 dB and to the device's own limits.
double clampGain(
  double db, {
  required double deviceMinDb,
  required double deviceMaxDb,
}) {
  final lower = math.max(-maxUserGainDb, deviceMinDb);
  final upper = math.min(maxUserGainDb, deviceMaxDb);
  return db.clamp(lower, upper).toDouble();
}
