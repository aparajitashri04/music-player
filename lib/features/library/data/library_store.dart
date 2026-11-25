import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/library_folder.dart';
import '../domain/track.dart';

/// Everything about the library that survives a restart. Bundled tracks are
/// not stored; only which of them the user removed.
class PersistedLibrary {
  const PersistedLibrary({
    this.imported = const [],
    this.removedBundled = const {},
    this.folders = const [],
    this.assignments = const {},
  });

  final List<Track> imported;
  final Set<String> removedBundled;
  final List<LibraryFolder> folders;

  /// Track id -> folder id.
  final Map<String, String> assignments;
}

abstract interface class LibraryStore {
  /// Returns an empty library when nothing has been saved yet.
  Future<PersistedLibrary> load();
  Future<void> save(PersistedLibrary library);
}

/// Stores the library as one small JSON file in the app support directory.
class JsonFileLibraryStore implements LibraryStore {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'library.json'));
  }

  @override
  Future<PersistedLibrary> load() async {
    final file = await _file();
    if (!await file.exists()) return const PersistedLibrary();
    return decodeLibrary(await file.readAsString());
  }

  @override
  Future<void> save(PersistedLibrary library) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    // Write to a temp file first so a crash cannot truncate the library.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(encodeLibrary(library), flush: true);
    await temp.rename(file.path);
  }
}

String encodeLibrary(PersistedLibrary library) => jsonEncode({
  'version': 1,
  'imported': [
    for (final t in library.imported)
      {
        'uri': t.uri,
        'title': t.title,
        'artist': t.artist,
        'album': t.album,
        'durationMs': t.duration?.inMilliseconds,
      },
  ],
  'removedBundled': library.removedBundled.toList(),
  'folders': [
    for (final f in library.folders) {'id': f.id, 'name': f.name},
  ],
  'assignments': library.assignments,
});

/// Malformed entries are skipped rather than failing the whole library.
PersistedLibrary decodeLibrary(String source) {
  final root = jsonDecode(source);
  if (root is! Map<String, dynamic>) return const PersistedLibrary();

  final imported = <Track>[];
  for (final entry in (root['imported'] as List? ?? const [])) {
    if (entry is! Map) continue;
    final uri = entry['uri'];
    final title = entry['title'];
    final artist = entry['artist'];
    if (uri is! String || title is! String || artist is! String) continue;
    final durationMs = entry['durationMs'];
    imported.add(
      Track(
        id: 'file:$uri',
        title: title,
        artist: artist,
        album: entry['album'] as String?,
        duration: durationMs is int && durationMs > 0
            ? Duration(milliseconds: durationMs)
            : null,
        uri: uri,
      ),
    );
  }

  final folders = <LibraryFolder>[];
  for (final entry in (root['folders'] as List? ?? const [])) {
    if (entry is Map && entry['id'] is String && entry['name'] is String) {
      folders.add(
        LibraryFolder(id: entry['id'] as String, name: entry['name'] as String),
      );
    }
  }

  final assignments = <String, String>{};
  final rawAssignments = root['assignments'];
  if (rawAssignments is Map) {
    rawAssignments.forEach((key, value) {
      if (key is String && value is String) assignments[key] = value;
    });
  }

  return PersistedLibrary(
    imported: imported,
    removedBundled: {
      for (final id in (root['removedBundled'] as List? ?? const []))
        if (id is String) id,
    },
    folders: folders,
    assignments: assignments,
  );
}
