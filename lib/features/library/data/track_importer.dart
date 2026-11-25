import 'package:file_picker/file_picker.dart';

import '../domain/track.dart';
import 'metadata_reader.dart';

class ImportResult {
  const ImportResult({this.tracks = const [], this.skipped = 0});

  final List<Track> tracks;

  /// Picked files that could not be addressed (no usable location).
  final int skipped;
}

class TrackImporter {
  TrackImporter(this._metadata);

  final MetadataReader _metadata;

  /// Opens the system audio picker. Returns an empty result if cancelled.
  Future<ImportResult> pickAndImport() async {
    final files = await FilePicker.pickFiles(
      type: FileType.audio,
      dialogTitle: 'Import audio files',
    );

    final tracks = <Track>[];
    var skipped = 0;
    for (final file in files) {
      final location = file.path ?? file.uri.toString();
      if (location.isEmpty) {
        skipped++;
        continue;
      }
      final uri = file.path != null
          ? Uri.file(file.path!).toString()
          : location;
      final metadata = await _metadata.read(uri);
      tracks.add(
        Track.fromImport(uri: uri, fileName: file.name, metadata: metadata),
      );
    }
    return ImportResult(tracks: tracks, skipped: skipped);
  }
}
