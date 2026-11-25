import 'package:flutter_test/flutter_test.dart';
import 'package:music_play/core/utils/duration_format.dart';

void main() {
  group('formatDuration', () {
    test('formats minutes and padded seconds', () {
      expect(formatDuration(Duration.zero), '0:00');
      expect(formatDuration(const Duration(seconds: 5)), '0:05');
      expect(formatDuration(const Duration(seconds: 222)), '3:42');
      expect(formatDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('adds hours from one hour up', () {
      expect(formatDuration(const Duration(hours: 1)), '1:00:00');
      expect(
        formatDuration(const Duration(hours: 2, minutes: 3, seconds: 4)),
        '2:03:04',
      );
    });

    test('truncates sub-second parts and clamps negatives', () {
      expect(formatDuration(const Duration(milliseconds: 1999)), '0:01');
      expect(formatDuration(const Duration(seconds: -10)), '0:00');
    });

    test('formatDurationOrUnknown handles null', () {
      expect(formatDurationOrUnknown(null), unknownDurationLabel);
      expect(formatDurationOrUnknown(const Duration(seconds: 61)), '1:01');
    });
  });
}
