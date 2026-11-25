import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_play/app/audio_backend.dart';
import 'package:music_play/features/equalizer/application/equalizer_notifier.dart';
import 'package:music_play/features/equalizer/domain/eq_band_mapping.dart';
import 'package:music_play/features/equalizer/domain/eq_state.dart';
import 'package:music_play/features/library/data/bundled_tracks.dart';

import '../helpers/fakes.dart';

Future<(ProviderContainer, FakePlaybackEngine, FakeEqualizerEngine)> setUpEq({
  FakeEqualizerEngine? eq,
}) async {
  final playback = FakePlaybackEngine();
  final equalizer = eq ?? FakeEqualizerEngine();
  final container = ProviderContainer(
    overrides: [
      playbackEngineProvider.overrideWithValue(playback),
      equalizerEngineProvider.overrideWithValue(equalizer),
    ],
  );
  addTearDown(container.dispose);
  container.read(equalizerProvider);
  await pumpEventQueue();
  return (container, playback, equalizer);
}

void main() {
  test('initialises, enables the effect and starts flat', () async {
    final (container, _, eq) = await setUpEq();
    final state = container.read(equalizerProvider);
    expect(state.status, EqStatus.ready);
    expect(eq.enabled, isTrue);
    expect(eq.gains.values, everyElement(0));
    expect(eq.gains.keys, hasLength(5));
  });

  test('a slider moves only the device bands mapped to it', () async {
    final (container, _, eq) = await setUpEq();
    await container.read(equalizerProvider.notifier).setGain(EqGroup.low, 6);
    expect(container.read(equalizerProvider).gains[EqGroup.low], 6);
    // 5-band device: low = bands 0 and 1 (60 Hz, 230 Hz).
    expect(eq.gains[0], 6);
    expect(eq.gains[1], 6);
    expect(eq.gains[2], 0);
    expect(eq.gains[3], 0);
    expect(eq.gains[4], 0);

    await container.read(equalizerProvider.notifier).setGain(EqGroup.high, -4);
    expect(eq.gains[4], -4);
    expect(eq.gains[0], 6);
  });

  test('gains are clamped to ±12 dB', () async {
    final (container, _, eq) = await setUpEq();
    final notifier = container.read(equalizerProvider.notifier);
    await notifier.setGain(EqGroup.mid, 40);
    expect(container.read(equalizerProvider).gains[EqGroup.mid], 12);
    expect(eq.gains[2], 12);
    await notifier.setGain(EqGroup.mid, -40);
    expect(eq.gains[2], -12);
  });

  test('gains are clamped to a narrower device range', () async {
    final (container, _, eq) = await setUpEq(
      eq: FakeEqualizerEngine(minDb: -6, maxDb: 6),
    );
    await container.read(equalizerProvider.notifier).setGain(EqGroup.low, 12);
    expect(container.read(equalizerProvider).maxDb, 6);
    expect(eq.gains[0], 6);
  });

  test('reset restores every band to 0 dB', () async {
    final (container, _, eq) = await setUpEq();
    final notifier = container.read(equalizerProvider.notifier);
    await notifier.setGain(EqGroup.low, 9);
    await notifier.setGain(EqGroup.mid, -7.5);
    await notifier.setGain(EqGroup.high, 12);
    expect(container.read(equalizerProvider).isFlat, isFalse);

    await notifier.reset();

    expect(container.read(equalizerProvider).isFlat, isTrue);
    expect(eq.gains.values, everyElement(0));
  });

  test('gains are re-applied to the engine after a track change', () async {
    final (container, playback, eq) = await setUpEq();
    await container.read(equalizerProvider.notifier).setGain(EqGroup.high, 8);
    expect(eq.gains[4], 8);

    // Simulate the native effect losing its settings across a source change.
    eq.gains.clear();
    eq.enabled = false;
    await playback.load(bundledTracks[1]);
    await pumpEventQueue();

    expect(eq.gains[4], 8);
    expect(eq.enabled, isTrue);
    expect(container.read(equalizerProvider).gains[EqGroup.high], 8);
  });

  test('disabling bypasses the effect without losing the settings', () async {
    final (container, _, eq) = await setUpEq();
    final notifier = container.read(equalizerProvider.notifier);
    await notifier.setGain(EqGroup.low, 5);
    await notifier.setEnabled(false);
    expect(eq.enabled, isFalse);
    expect(container.read(equalizerProvider).gains[EqGroup.low], 5);
  });

  test('unsupported platforms report it and ignore changes', () async {
    final (container, _, eq) = await setUpEq(
      eq: FakeEqualizerEngine(supported: false),
    );
    final state = container.read(equalizerProvider);
    expect(state.status, EqStatus.unsupported);
    expect(state.message, isNotEmpty);

    await container.read(equalizerProvider.notifier).setGain(EqGroup.low, 5);
    expect(container.read(equalizerProvider).gains[EqGroup.low], 0);
    expect(eq.gains, isEmpty);
  });

  test(
    'an initialisation failure surfaces as an error and can be retried',
    () async {
      final eq = FakeEqualizerEngine()..failInitialize = true;
      final (container, _, _) = await setUpEq(eq: eq);
      expect(container.read(equalizerProvider).status, EqStatus.error);
      expect(container.read(equalizerProvider).message, isNotEmpty);

      eq.failInitialize = false;
      await container.read(equalizerProvider.notifier).retry();
      expect(container.read(equalizerProvider).status, EqStatus.ready);
    },
  );

  test('a device rejecting a change surfaces as an error', () async {
    final (container, _, eq) = await setUpEq();
    eq.failSetGain = true;
    await container.read(equalizerProvider.notifier).setGain(EqGroup.low, 3);
    expect(container.read(equalizerProvider).status, EqStatus.error);
  });
}
