import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_play/features/player/presentation/widgets/playback_controls.dart';

Widget host({
  bool isPlaying = false,
  bool isLoading = false,
  bool enabled = true,
  VoidCallback? onPrevious,
  VoidCallback? onPlayPause,
  VoidCallback? onNext,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: PlaybackControls(
          isPlaying: isPlaying,
          isLoading: isLoading,
          enabled: enabled,
          onPrevious: onPrevious ?? () {},
          onPlayPause: onPlayPause ?? () {},
          onNext: onNext ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('buttons fire their callbacks', (tester) async {
    var previous = 0, toggle = 0, next = 0;
    await tester.pumpWidget(
      host(
        onPrevious: () => previous++,
        onPlayPause: () => toggle++,
        onNext: () => next++,
      ),
    );

    await tester.tap(find.byTooltip('Previous'));
    await tester.tap(find.byTooltip('Next'));
    await tester.tap(find.bySemanticsLabel('Play'));

    expect((previous, toggle, next), (1, 1, 1));
  });

  testWidgets('shows play when paused and pause when playing', (tester) async {
    await tester.pumpWidget(host(isPlaying: false));
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);

    await tester.pumpWidget(host(isPlaying: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    await tester.pumpWidget(host(isLoading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('skip buttons are disabled without a track', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(enabled: false, onPrevious: () => taps++, onNext: () => taps++),
    );
    await tester.tap(find.byTooltip('Previous'), warnIfMissed: false);
    await tester.tap(find.byTooltip('Next'), warnIfMissed: false);
    expect(taps, 0);
  });
}
