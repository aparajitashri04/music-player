import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bundled_tracks.dart';
import '../data/library_store.dart';
import '../data/metadata_reader.dart';
import '../data/track_importer.dart';
import '../domain/library_folder.dart';
import '../domain/track.dart';

final metadataReaderProvider = Provider<MetadataReader>(
  (ref) => createMetadataReader(),
);

final trackImporterProvider = Provider<TrackImporter>(
  (ref) => TrackImporter(ref.watch(metadataReaderProvider)),
);

final libraryStoreProvider = Provider<LibraryStore>(
  (ref) => JsonFileLibraryStore(),
);

class ImportOutcome {
  const ImportOutcome({this.added = 0, this.duplicates = 0, this.skipped = 0});

  final int added;
  final int duplicates;
  final int skipped;

  bool get isEmpty => added == 0 && duplicates == 0 && skipped == 0;
}

/// What [LibraryNotifier.removeTrack] took out, so it can be undone.
class RemovedTrack {
  const RemovedTrack(this.track, this.index, this.folderId);

  final Track track;
  final int index;
  final String? folderId;
}

class LibraryState {
  const LibraryState({
    required this.tracks,
    this.folders = const [],
    this.assignments = const {},
    this.isImporting = false,
  });

  /// Every track in the library. This order is the playback queue.
  final List<Track> tracks;
  final List<LibraryFolder> folders;

  /// Track id -> folder id. Tracks without an entry are unfiled.
  final Map<String, String> assignments;
  final bool isImporting;

  List<Track> inFolder(String folderId) => [
    for (final t in tracks)
      if (assignments[t.id] == folderId) t,
  ];

  List<Track> get unfiled => [
    for (final t in tracks)
      if (assignments[t.id] == null) t,
  ];

  LibraryState copyWith({
    List<Track>? tracks,
    List<LibraryFolder>? folders,
    Map<String, String>? assignments,
    bool? isImporting,
  }) => LibraryState(
    tracks: tracks ?? this.tracks,
    folders: folders ?? this.folders,
    assignments: assignments ?? this.assignments,
    isImporting: isImporting ?? this.isImporting,
  );
}

class LibraryNotifier extends Notifier<LibraryState> {
  Set<String> _removedBundled = {};
  late Future<void> _loaded;
  int _folderCounter = 0;

  @override
  LibraryState build() {
    _loaded = _load();
    return LibraryState(tracks: List.unmodifiable(bundledTracks));
  }

  Future<void> _load() async {
    try {
      final saved = await ref.read(libraryStoreProvider).load();
      if (!ref.mounted) return;
      _removedBundled = {...saved.removedBundled};
      final known = <String>{};
      final tracks = <Track>[
        for (final t in [...state.tracks, ...saved.imported])
          if (!_removedBundled.contains(t.id) && known.add(t.id)) t,
      ];
      final folderIds = {for (final f in saved.folders) f.id};
      state = state.copyWith(
        tracks: List.unmodifiable(tracks),
        folders: List.unmodifiable(saved.folders),
        assignments: {
          for (final e in saved.assignments.entries)
            if (known.contains(e.key) && folderIds.contains(e.value))
              e.key: e.value,
        },
      );
    } on Object catch (error) {
      // Start with the bundled tracks if the saved library cannot be read.
      debugPrint('Could not load the saved library: $error');
    }
  }

  Future<void> _persist() async {
    await _loaded;
    if (!ref.mounted) return;
    try {
      await ref
          .read(libraryStoreProvider)
          .save(
            PersistedLibrary(
              imported: [
                for (final t in state.tracks)
                  if (!t.isBundled) t,
              ],
              removedBundled: _removedBundled,
              folders: state.folders,
              assignments: state.assignments,
            ),
          );
    } on Object catch (error) {
      debugPrint('Could not save the library: $error');
    }
  }

  /// Throws if the system picker or file access fails; the UI reports it.
  Future<ImportOutcome> importFiles() async {
    if (state.isImporting) return const ImportOutcome();
    state = state.copyWith(isImporting: true);
    try {
      final result = await ref.read(trackImporterProvider).pickAndImport();
      final known = state.tracks.map((t) => t.id).toSet();
      final fresh = <Track>[];
      var duplicates = 0;
      for (final track in result.tracks) {
        if (known.add(track.id)) {
          fresh.add(track);
        } else {
          duplicates++;
        }
      }
      if (fresh.isNotEmpty) {
        state = state.copyWith(
          tracks: List.unmodifiable([...state.tracks, ...fresh]),
        );
        unawaited(_persist());
      }
      return ImportOutcome(
        added: fresh.length,
        duplicates: duplicates,
        skipped: result.skipped,
      );
    } finally {
      state = state.copyWith(isImporting: false);
    }
  }

  /// Removes the track from the library only; the audio file is never touched.
  RemovedTrack? removeTrack(String trackId) {
    final index = state.tracks.indexWhere((t) => t.id == trackId);
    if (index < 0) return null;
    final track = state.tracks[index];
    final folderId = state.assignments[trackId];
    if (track.isBundled) _removedBundled = {..._removedBundled, track.id};
    state = state.copyWith(
      tracks: List.unmodifiable([...state.tracks]..removeAt(index)),
      assignments: {...state.assignments}..remove(trackId),
    );
    unawaited(_persist());
    return RemovedTrack(track, index, folderId);
  }

  void restoreTrack(RemovedTrack removed) {
    if (state.tracks.any((t) => t.id == removed.track.id)) return;
    _removedBundled = {..._removedBundled}..remove(removed.track.id);
    final tracks = [...state.tracks];
    tracks.insert(removed.index.clamp(0, tracks.length), removed.track);
    final folderId = removed.folderId;
    state = state.copyWith(
      tracks: List.unmodifiable(tracks),
      assignments: {
        ...state.assignments,
        if (folderId != null && state.folders.any((f) => f.id == folderId))
          removed.track.id: folderId,
      },
    );
    unawaited(_persist());
  }

  /// Returns the new folder, or null if [name] is blank.
  LibraryFolder? createFolder(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final folder = LibraryFolder(
      id: 'folder:${DateTime.now().microsecondsSinceEpoch}:${_folderCounter++}',
      name: trimmed,
    );
    state = state.copyWith(
      folders: List.unmodifiable([...state.folders, folder]),
    );
    unawaited(_persist());
    return folder;
  }

  void renameFolder(String folderId, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(
      folders: List.unmodifiable([
        for (final f in state.folders)
          if (f.id == folderId) f.rename(trimmed) else f,
      ]),
    );
    unawaited(_persist());
  }

  /// Tracks inside the folder go back to the unfiled list; none are removed.
  void deleteFolder(String folderId) {
    state = state.copyWith(
      folders: List.unmodifiable([
        for (final f in state.folders)
          if (f.id != folderId) f,
      ]),
      assignments: {
        for (final e in state.assignments.entries)
          if (e.value != folderId) e.key: e.value,
      },
    );
    unawaited(_persist());
  }

  /// Moves several tracks at once (selection or drag and drop) with a single
  /// save. A null [folderId] moves them back to the unfiled list.
  void moveTracksToFolder(Iterable<String> trackIds, String? folderId) {
    if (folderId != null && !state.folders.any((f) => f.id == folderId)) return;
    final known = state.tracks.map((t) => t.id).toSet();
    final assignments = {...state.assignments};
    for (final id in trackIds) {
      if (!known.contains(id)) continue;
      if (folderId == null) {
        assignments.remove(id);
      } else {
        assignments[id] = folderId;
      }
    }
    state = state.copyWith(assignments: assignments);
    unawaited(_persist());
  }

  /// A null [folderId] moves the track back to the unfiled list.
  void moveToFolder(String trackId, String? folderId) {
    if (!state.tracks.any((t) => t.id == trackId)) return;
    if (folderId != null && !state.folders.any((f) => f.id == folderId)) return;
    final assignments = {...state.assignments};
    if (folderId == null) {
      assignments.remove(trackId);
    } else {
      assignments[trackId] = folderId;
    }
    state = state.copyWith(assignments: assignments);
    unawaited(_persist());
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(
  LibraryNotifier.new,
);
