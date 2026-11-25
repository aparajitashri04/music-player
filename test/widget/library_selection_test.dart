import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_play/app/audio_backend.dart';
import 'package:music_play/core/theme/app_theme.dart';
import 'package:music_play/features/library/application/library_notifier.dart';
import 'package:music_play/features/library/data/bundled_tracks.dart';
import 'package:music_play/features/library/presentation/library_screen.dart';
import 'package:music_play/features/player/application/player_notifier.dart';

import '../helpers/fakes.dart';

void main() {
  libraryManagementTests();
  testWidgets('tapping a track selects it and starts playback', (tester) async {
    final engine = FakePlaybackEngine();
    final container = ProviderContainer(
      overrides: [
        playbackEngineProvider.overrideWithValue(engine),
        equalizerEngineProvider.overrideWithValue(FakeEqualizerEngine()),
        libraryStoreProvider.overrideWithValue(MemoryLibraryStore()),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var navigated = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: LibraryScreen(onTrackSelected: () => navigated++),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Library'), findsOneWidget);
    for (final track in bundledTracks) {
      expect(find.text(track.title), findsOneWidget);
    }

    await tester.tap(find.text('Glass Garden'));
    await tester.pump();
    await tester.pump();

    final state = container.read(playerProvider);
    expect(state.current?.title, 'Glass Garden');
    expect(state.isPlaying, isTrue);
    expect(engine.loaded.last, 'bundled:glass_garden');
    expect(navigated, 1);
  });
}

void libraryManagementTests() {
  testWidgets('long press selects, tap adds, dragging moves them to a folder', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
        equalizerEngineProvider.overrideWithValue(FakeEqualizerEngine()),
        libraryStoreProvider.overrideWithValue(MemoryLibraryStore()),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: LibraryScreen()),
        ),
      ),
    );
    await tester.pump();
    final folder = container
        .read(libraryProvider.notifier)
        .createFolder('Mix')!;
    await tester.pump();

    final first = bundledTracks[0];
    final second = bundledTracks[1];
    await tester.longPress(find.text(first.title));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    // A tap while selecting adds to the selection instead of playing.
    await tester.tap(find.text(second.title));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text(first.title)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveTo(tester.getCenter(find.text('Mix')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final state = container.read(libraryProvider);
    expect(state.inFolder(folder.id), [first, second]);
    expect(find.textContaining('selected'), findsNothing);
    expect(find.textContaining('Moved 2 tracks'), findsOneWidget);
  });

  testWidgets('removing a track from its menu offers undo', (tester) async {
    final container = ProviderContainer(
      overrides: [
        playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
        equalizerEngineProvider.overrideWithValue(FakeEqualizerEngine()),
        libraryStoreProvider.overrideWithValue(MemoryLibraryStore()),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: LibraryScreen()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Track options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from library'));
    await tester.pumpAndSettle();
    expect(find.text(bundledTracks.first.title), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text(bundledTracks.first.title), findsOneWidget);
  });
}
