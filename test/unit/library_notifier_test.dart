import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_play/app/audio_backend.dart';
import 'package:music_play/core/theme/app_theme.dart';
import 'package:music_play/features/library/application/library_notifier.dart';
import 'package:music_play/features/library/data/bundled_tracks.dart';
import 'package:music_play/features/library/data/library_store.dart';
import 'package:music_play/features/library/domain/track.dart';
import 'package:music_play/features/player/application/player_notifier.dart';
import 'package:music_play/shared/widgets/album_art.dart';

import '../helpers/fakes.dart';

const imported = Track(
  id: 'file:file:///music/a.mp3',
  title: 'Imported',
  artist: 'Someone',
  duration: Duration(seconds: 90),
  uri: 'file:///music/a.mp3',
);

Future<(ProviderContainer, MemoryLibraryStore, FakePlaybackEngine)> setUp({
  PersistedLibrary saved = const PersistedLibrary(),
}) async {
  final store = MemoryLibraryStore(saved);
  final engine = FakePlaybackEngine();
  final container = ProviderContainer(
    overrides: [
      libraryStoreProvider.overrideWithValue(store),
      playbackEngineProvider.overrideWithValue(engine),
      equalizerEngineProvider.overrideWithValue(FakeEqualizerEngine()),
    ],
  );
  addTearDown(container.dispose);
  container.read(libraryProvider);
  await pumpEventQueue();
  return (container, store, engine);
}

void main() {
  test('loads imported tracks, folders and removals from the store', () async {
    final (container, _, _) = await setUp(
      saved: PersistedLibrary(
        imported: const [imported],
        removedBundled: {bundledTracks.first.id},
      ),
    );
    final tracks = container.read(libraryProvider).tracks;
    expect(tracks, contains(imported));
    expect(tracks, isNot(contains(bundledTracks.first)));
  });

  test('removing a track drops it, persists, and undo restores it', () async {
    final (container, store, _) = await setUp();
    final notifier = container.read(libraryProvider.notifier);
    final victim = bundledTracks[1];

    final removed = notifier.removeTrack(victim.id)!;
    await pumpEventQueue();
    expect(container.read(libraryProvider).tracks, isNot(contains(victim)));
    expect(store.data.removedBundled, {victim.id});

    notifier.restoreTrack(removed);
    await pumpEventQueue();
    final tracks = container.read(libraryProvider).tracks;
    expect(tracks.indexOf(victim), 1);
    expect(store.data.removedBundled, isEmpty);
  });

  test('folders can be created, filled, renamed and deleted', () async {
    final (container, store, _) = await setUp();
    final notifier = container.read(libraryProvider.notifier);
    final track = bundledTracks.first;

    expect(notifier.createFolder('   '), isNull);
    final folder = notifier.createFolder('  Chill ')!;
    expect(folder.name, 'Chill');

    notifier.moveToFolder(track.id, folder.id);
    var state = container.read(libraryProvider);
    expect(state.inFolder(folder.id), [track]);
    expect(state.unfiled, isNot(contains(track)));

    notifier.renameFolder(folder.id, 'Late night');
    expect(container.read(libraryProvider).folders.single.name, 'Late night');

    notifier.moveToFolder(track.id, null);
    expect(container.read(libraryProvider).inFolder(folder.id), isEmpty);

    notifier.moveToFolder(track.id, folder.id);
    notifier.deleteFolder(folder.id);
    await pumpEventQueue();
    state = container.read(libraryProvider);
    expect(state.folders, isEmpty);
    expect(state.tracks, contains(track)); // tracks survive folder deletion
    expect(state.unfiled, contains(track));
    expect(store.data.folders, isEmpty);
  });

  test('several tracks can be moved into a folder in one go', () async {
    final (container, store, _) = await setUp();
    final notifier = container.read(libraryProvider.notifier);
    final folder = notifier.createFolder('Mix')!;
    final ids = [bundledTracks[0].id, bundledTracks[2].id, 'file:nope'];

    notifier.moveTracksToFolder(ids, folder.id);
    await pumpEventQueue();
    final state = container.read(libraryProvider);
    expect(state.inFolder(folder.id), [bundledTracks[0], bundledTracks[2]]);
    expect(store.data.assignments.keys, hasLength(2));

    notifier.moveTracksToFolder(ids, null);
    expect(container.read(libraryProvider).inFolder(folder.id), isEmpty);
  });

  test('library survives a round trip through the JSON encoding', () {
    final data = PersistedLibrary(
      imported: const [imported],
      removedBundled: {'bundled:x'},
      folders: const [],
      assignments: {imported.id: 'folder:1'},
    );
    final decoded = decodeLibrary(encodeLibrary(data));
    expect(decoded.imported.single.uri, imported.uri);
    expect(decoded.imported.single.duration, imported.duration);
    expect(decoded.removedBundled, {'bundled:x'});
    expect(decoded.assignments, {imported.id: 'folder:1'});
    expect(decodeLibrary('[]').imported, isEmpty);
  });

  test('removing the playing track moves on to its neighbour', () async {
    final (container, _, engine) = await setUp();
    final player = container.read(playerProvider.notifier);
    await player.selectTrack(bundledTracks[1]);
    await pumpEventQueue();
    expect(container.read(playerProvider).isPlaying, isTrue);

    container.read(libraryProvider.notifier).removeTrack(bundledTracks[1].id);
    await pumpEventQueue();

    final state = container.read(playerProvider);
    expect(state.current, bundledTracks[2]);
    expect(state.isPlaying, isTrue);
    expect(engine.loaded.last, bundledTracks[2].id);
  });

  test('removing every track clears the player', () async {
    final (container, _, _) = await setUp();
    container.read(playerProvider);
    await pumpEventQueue();
    final notifier = container.read(libraryProvider.notifier);
    for (final t in [...bundledTracks]) {
      notifier.removeTrack(t.id);
    }
    await pumpEventQueue();
    expect(container.read(playerProvider).current, isNull);
    expect(container.read(playerProvider).isPlaying, isFalse);
  });

  test('artwork colour is a stable muted pink from the palette', () {
    final colour = AlbumArt.colorFor('bundled:low_tide');
    expect(AppColors.artPalette, contains(colour));
    expect(AlbumArt.colorFor('bundled:low_tide'), colour);
    expect(Color(colour.toARGB32()).a, 1);
  });
}
