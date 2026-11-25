import 'package:flutter/foundation.dart';

/// A named, in-app grouping of tracks. Folders never touch files on disk.
@immutable
class LibraryFolder {
  const LibraryFolder({required this.id, required this.name});

  final String id;
  final String name;

  LibraryFolder rename(String name) => LibraryFolder(id: id, name: name);

  @override
  bool operator ==(Object other) =>
      other is LibraryFolder && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
