import 'package:flutter_test/flutter_test.dart';
import 'package:music_play/features/library/data/bundled_tracks.dart';
import 'package:music_play/features/library/domain/track.dart';

void main() {
  group('Track.fromImport', () {
    test('uses tags when present', () {
      final track = Track.fromImport(
        uri: 'file:///music/a.mp3',
        fileName: 'a.mp3',
        metadata: const TrackMetadata(
          title: '  Song  ',
          artist: 'Band',
          album: 'LP',
          duration: Duration(seconds: 200),
        ),
      );
      expect(track.title, 'Song');
      expect(track.artist, 'Band');
      expect(track.album, 'LP');
      expect(track.duration, const Duration(seconds: 200));
      expect(track.isBundled, isFalse);
    });

    test('falls back to the file name and unknown artist', () {
      final track = Track.fromImport(
        uri: 'file:///music/my_great_song.flac',
        fileName: 'my_great_song.flac',
      );
      expect(track.title, 'my great song');
      expect(track.artist, unknownArtist);
      expect(track.duration, isNull);
    });

    test('treats blank tags and zero duration as missing', () {
      final track = Track.fromImport(
        uri: 'file:///x/clip.wav',
        fileName: 'clip.wav',
        metadata: const TrackMetadata(
          title: '   ',
          artist: '',
          duration: Duration.zero,
        ),
      );
      expect(track.title, 'clip');
      expect(track.artist, unknownArtist);
      expect(track.duration, isNull);
    });
  });

  test('titleFromFileName never returns an empty title', () {
    expect(Track.titleFromFileName('.mp3'), isNotEmpty);
    expect(Track.titleFromFileName('Track_01.mp3'), 'Track 01');
  });

  test('tracks are equal by id', () {
    const a = Track(id: 'x', title: 'A', artist: 'a', assetPath: 'p');
    const b = Track(id: 'x', title: 'B', artist: 'b', uri: 'file:///q');
    expect(a, b);
    expect({a, b}, hasLength(1));
  });

  test('bundled tracks are unique, bundled and have durations', () {
    expect(bundledTracks, hasLength(greaterThanOrEqualTo(3)));
    expect(
      bundledTracks.map((t) => t.id).toSet(),
      hasLength(bundledTracks.length),
    );
    for (final track in bundledTracks) {
      expect(track.isBundled, isTrue);
      expect(track.duration, isNotNull);
    }
  });
}
