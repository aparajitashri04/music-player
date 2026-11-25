import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_play/app/audio_backend.dart';
import 'package:music_play/core/theme/app_theme.dart';
import 'package:music_play/features/equalizer/application/equalizer_notifier.dart';
import 'package:music_play/features/equalizer/domain/eq_band_mapping.dart';
import 'package:music_play/features/equalizer/presentation/equalizer_screen.dart';

import 'package:music_play/features/equalizer/data/unsupported_equalizer_engine.dart';

import '../helpers/fakes.dart';

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  FakeEqualizerEngine eq,
) async {
  final container = ProviderContainer(
    overrides: [
      playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
      equalizerEngineProvider.overrideWithValue(eq),
    ],
  );
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: EqualizerScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

Slider sliderFor(WidgetTester tester, String label) =>
    tester.widget<Slider>(find.byKey(ValueKey('eq-slider-$label')));

void main() {
  testWidgets('unsupported platforms show a message and no controls', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
        equalizerEngineProvider.overrideWithValue(
          const UnsupportedEqualizerEngine('Windows has no equalizer.'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: EqualizerScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Equalizer is available on Android only.'), findsOne);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Reset'), findsNothing);
  });

  testWidgets('renders Low, Mid and High sliders at 0 dB', (tester) async {
    await pumpScreen(tester, FakeEqualizerEngine());

    for (final label in ['Low', 'Mid', 'High']) {
      final slider = sliderFor(tester, label);
      expect(slider.value, 0);
      expect(slider.min, -12);
      expect(slider.max, 12);
      expect(slider.onChanged, isNotNull);
    }
    expect(find.text('0 dB'), findsNWidgets(3));
  });

  testWidgets('dragging a slider changes its gain and the engine', (
    tester,
  ) async {
    final eq = FakeEqualizerEngine();
    final container = await pumpScreen(tester, eq);

    await tester.drag(
      find.byKey(const ValueKey('eq-slider-High')),
      const Offset(0, -80),
    );
    await tester.pump();

    final high = sliderFor(tester, 'High').value;
    expect(high, greaterThan(0));
    expect(sliderFor(tester, 'Low').value, 0);
    expect(eq.gains[4], high);
    expect(container.read(equalizerProvider).isFlat, isFalse);
  });

  testWidgets('Reset returns every slider and band to 0 dB', (tester) async {
    final eq = FakeEqualizerEngine();
    final container = await pumpScreen(tester, eq);
    final notifier = container.read(equalizerProvider.notifier);
    await notifier.setGain(EqGroup.low, 6);
    await notifier.setGain(EqGroup.high, -9);
    await tester.pump();
    expect(find.text('+6.0 dB'), findsOneWidget);
    expect(find.text('−9.0 dB'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();

    for (final label in ['Low', 'Mid', 'High']) {
      expect(sliderFor(tester, label).value, 0);
    }
    expect(eq.gains.values, everyElement(0));
  });

  testWidgets('unsupported engine hides the sliders and explains why', (
    tester,
  ) async {
    await pumpScreen(tester, FakeEqualizerEngine(supported: false));

    expect(find.text('Equalizer is available on Android only.'), findsOne);
    expect(find.text('Not available in tests.'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('an engine failure shows an error with a retry action', (
    tester,
  ) async {
    final eq = FakeEqualizerEngine()..failInitialize = true;
    await pumpScreen(tester, eq);

    expect(find.text('No equalizer on this device.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(sliderFor(tester, 'Low').onChanged, isNull);
  });
}
