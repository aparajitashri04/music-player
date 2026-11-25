import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_play/app/audio_backend.dart';
import 'package:music_play/features/library/application/library_notifier.dart';
import 'package:music_play/features/library/data/bundled_tracks.dart';
import 'package:music_play/features/player/application/player_notifier.dart';

import '../helpers/fakes.dart';

final first = bundledTracks[0];
final second = bundledTracks[1];
final last = bundledTracks.last;

Future<(ProviderContainer, FakePlaybackEngine)> setUpPlayer() async {
  final engine = FakePlaybackEngine();
  final container = ProviderContainer(
    overrides: [
      playbackEngineProvider.overrideWithValue(engine),
      equalizerEngineProvider.overrideWithValue(FakeEqualizerEngine()),
      libraryStoreProvider.overrideWithValue(MemoryLibraryStore()),
    ],
  );
  addTearDown(container.dispose);
  container.read(playerProvider);
  await pumpEventQueue();
  return (container, engine);
}

void main() {
  test('preloads the first track without starting playback', () async {
    final (container, engine) = await setUpPlayer();
    final state = container.read(playerProvider);
    expect(state.current, first);
    expect(state.isPlaying, isFalse);
    expect(state.isLoading, isFalse);
    expect(engine.loaded, [first.id]);
  });

  test('selecting a track loads and plays it', () async {
    final (container, engine) = await setUpPlayer();
    await container.read(playerProvider.notifier).selectTrack(second);
    await pumpEventQueue();

    final state = container.read(playerProvider);
    expect(state.current, second);
    expect(state.isPlaying, isTrue);
    expect(state.duration, second.duration);
    expect(engine.loaded.last, second.id);
  });

  test('play/pause toggles and the state follows the engine', () async {
    final (container, engine) = await setUpPlayer();
    final notifier = container.read(playerProvider.notifier);

    await notifier.togglePlayPause();
    await pumpEventQueue();
    expect(container.read(playerProvider).isPlaying, isTrue);
    expect(engine.playing, isTrue);

    await notifier.togglePlayPause();
    await pumpEventQueue();
    expect(container.read(playerProvider).isPlaying, isFalse);
    expect(engine.playing, isFalse);
  });

  test(
    'next advances, wraps from the last track, previous goes back',
    () async {
      final (container, _) = await setUpPlayer();
      final notifier = container.read(playerProvider.notifier);

      await notifier.next();
      expect(container.read(playerProvider).current, second);

      await notifier.previous();
      expect(container.read(playerProvider).current, first);

      await notifier.selectTrack(last);
      await notifier.next();
      expect(container.read(playerProvider).current, first);
    },
  );

  test(
    'previous restarts the track when it has played past the threshold',
    () async {
      final (container, engine) = await setUpPlayer();
      final notifier = container.read(playerProvider.notifier);
      await notifier.selectTrack(second);
      engine.emitPosition(const Duration(seconds: 10));
      await pumpEventQueue();

      await notifier.previous();

      expect(container.read(playerProvider).current, second);
      expect(engine.seeks.last, Duration.zero);
    },
  );

  test('previous on the first track restarts it', () async {
    final (container, engine) = await setUpPlayer();
    await container.read(playerProvider.notifier).previous();
    expect(container.read(playerProvider).current, first);
    expect(engine.seeks.last, Duration.zero);
  });

  test('a finished track advances to the next one', () async {
    final (container, engine) = await setUpPlayer();
    await container.read(playerProvider.notifier).selectTrack(first);
    engine.emitCompleted();
    await pumpEventQueue();

    expect(container.read(playerProvider).current, second);
    expect(container.read(playerProvider).isPlaying, isTrue);
  });

  test('the last track finishing stops playback and rewinds', () async {
    final (container, engine) = await setUpPlayer();
    await container.read(playerProvider.notifier).selectTrack(last);
    engine.emitCompleted();
    await pumpEventQueue();

    final state = container.read(playerProvider);
    expect(state.current, last);
    expect(state.isPlaying, isFalse);
    expect(engine.seeks.last, Duration.zero);
  });

  test(
    'a track that fails to load reports the error and does not play',
    () async {
      final (container, engine) = await setUpPlayer();
      engine.failing.add(second.id);
      final notifier = container.read(playerProvider.notifier);

      await notifier.selectTrack(second);
      await pumpEventQueue();

      final state = container.read(playerProvider);
      expect(state.current, second);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
      expect(state.isPlaying, isFalse);

      // Pressing play retries; once the file is readable it plays.
      engine.failing.clear();
      await notifier.togglePlayPause();
      await pumpEventQueue();
      expect(container.read(playerProvider).error, isNull);
      expect(container.read(playerProvider).isPlaying, isTrue);
    },
  );

  test(
    'rapid switching ends on the last request and ignores stale loads',
    () async {
      final (container, engine) = await setUpPlayer();
      final notifier = container.read(playerProvider.notifier);
      final gate = engine.gates[second.id] = Completer<void>();

      final slow = notifier.selectTrack(second); // blocked on its gate
      await pumpEventQueue();
      final fast = notifier.selectTrack(last); // supersedes it
      await fast;
      gate.complete();
      await slow;
      await pumpEventQueue();

      final state = container.read(playerProvider);
      expect(state.current, last);
      expect(state.isLoading, isFalse);
      expect(state.isPlaying, isTrue);
      expect(engine.loaded, isNot(contains(second.id)));
    },
  );

  test('seek is clamped to the track duration', () async {
    final (container, engine) = await setUpPlayer();
    final notifier = container.read(playerProvider.notifier);

    await notifier.seek(const Duration(hours: 1));
    expect(engine.seeks.last, first.duration);
    await notifier.seek(const Duration(seconds: -5));
    expect(engine.seeks.last, Duration.zero);
  });

  test('seek is ignored while a track is loading', () async {
    final (container, engine) = await setUpPlayer();
    final notifier = container.read(playerProvider.notifier);
    engine.gates[second.id] = Completer<void>();
    unawaited(notifier.selectTrack(second));
    await pumpEventQueue();

    await notifier.seek(const Duration(seconds: 5));
    expect(engine.seeks, isEmpty);
  });
}
