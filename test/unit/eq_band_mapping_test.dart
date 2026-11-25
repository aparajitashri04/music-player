import 'package:flutter_test/flutter_test.dart';
import 'package:music_play/features/equalizer/domain/eq_band_mapping.dart';
import 'package:music_play/features/equalizer/domain/equalizer_engine.dart';

List<DeviceBand> bands(List<double> centers) => [
  for (var i = 0; i < centers.length; i++)
    DeviceBand(index: i, centerHz: centers[i]),
];

void main() {
  group('groupForFrequency', () {
    test('splits at the crossovers', () {
      expect(groupForFrequency(60), EqGroup.low);
      expect(groupForFrequency(250), EqGroup.low);
      expect(groupForFrequency(250.1), EqGroup.mid);
      expect(groupForFrequency(4000), EqGroup.mid);
      expect(groupForFrequency(4000.1), EqGroup.high);
      expect(groupForFrequency(16000), EqGroup.high);
    });
  });

  group('mapBandsToGroups', () {
    test('maps a typical 5-band device', () {
      final map = mapBandsToGroups(bands([60, 230, 910, 3600, 14000]));
      expect(map[EqGroup.low], [0, 1]);
      expect(map[EqGroup.mid], [2, 3]);
      expect(map[EqGroup.high], [4]);
    });

    test('maps a 10-band device', () {
      final map = mapBandsToGroups(
        bands([31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]),
      );
      expect(map[EqGroup.low], [0, 1, 2, 3]);
      expect(map[EqGroup.mid], [4, 5, 6, 7]);
      expect(map[EqGroup.high], [8, 9]);
    });

    test(
      'every band belongs to exactly one slider when all ranges are covered',
      () {
        final map = mapBandsToGroups(bands([60, 230, 910, 3600, 14000]));
        final all = map.values.expand((e) => e).toList()..sort();
        expect(all, [0, 1, 2, 3, 4]);
      },
    );

    test('an empty range borrows the nearest band on a log scale', () {
      // No band above 4 kHz: High should borrow the closest one (3 kHz).
      final map = mapBandsToGroups(bands([60, 1000, 3000]));
      expect(map[EqGroup.low], [0]);
      expect(map[EqGroup.mid], [1, 2]);
      expect(map[EqGroup.high], [2]);
    });

    test('a single band drives all three sliders', () {
      final map = mapBandsToGroups(bands([1000]));
      expect(map.values.every((v) => v.length == 1 && v.first == 0), isTrue);
    });

    test('no bands yields empty groups', () {
      final map = mapBandsToGroups(const []);
      expect(map.values.every((v) => v.isEmpty), isTrue);
    });
  });

  group('clampGain', () {
    test('limits to ±12 dB when the device allows more', () {
      expect(clampGain(20, deviceMinDb: -15, deviceMaxDb: 15), 12);
      expect(clampGain(-20, deviceMinDb: -15, deviceMaxDb: 15), -12);
    });

    test('respects narrower device limits', () {
      expect(clampGain(10, deviceMinDb: -6, deviceMaxDb: 6), 6);
      expect(clampGain(-10, deviceMinDb: -6, deviceMaxDb: 6), -6);
    });

    test('passes in-range values through', () {
      expect(clampGain(3.5, deviceMinDb: -15, deviceMaxDb: 15), 3.5);
      expect(clampGain(0, deviceMinDb: -15, deviceMaxDb: 15), 0);
    });
  });
}
