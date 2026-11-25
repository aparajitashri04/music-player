import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../features/equalizer/data/android_equalizer_engine.dart';
import '../features/equalizer/data/unsupported_equalizer_engine.dart';
import '../features/equalizer/domain/equalizer_engine.dart';
import '../features/player/data/just_audio_playback_engine.dart';
import '../features/player/domain/playback_engine.dart';

/// The playback and equalizer engines share one native player, so they are
/// created together here and exposed through separate interfaces.
class AudioBackend {
  AudioBackend({required this.playback, required this.equalizer});

  final PlaybackEngine playback;
  final EqualizerEngine equalizer;

  factory AudioBackend.forCurrentPlatform() {
    if (Platform.isAndroid) {
      final equalizer = AndroidEqualizer();
      final player = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]),
      );
      return AudioBackend(
        playback: JustAudioPlaybackEngine(player),
        equalizer: AndroidEqualizerEngine(equalizer),
      );
    }
    return AudioBackend(
      playback: JustAudioPlaybackEngine(AudioPlayer()),
      equalizer: const UnsupportedEqualizerEngine(
        'The equalizer is only available on Android in this version.',
      ),
    );
  }
}

final audioBackendProvider = Provider<AudioBackend>((ref) {
  final backend = AudioBackend.forCurrentPlatform();
  _configureSession();
  ref.onDispose(backend.playback.dispose);
  return backend;
});

final playbackEngineProvider = Provider<PlaybackEngine>(
  (ref) => ref.watch(audioBackendProvider).playback,
);

final equalizerEngineProvider = Provider<EqualizerEngine>(
  (ref) => ref.watch(audioBackendProvider).equalizer,
);

/// Audio focus / interruption handling exists only on Android and iOS. Other
/// platforms skip it entirely rather than depending on a mobile plugin.
Future<void> _configureSession() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } on Object catch (error, stack) {
    // Playback still works without it, so do not crash startup, but make the
    // failure visible instead of hiding it.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'music_play',
        context: ErrorDescription('while configuring the audio session'),
      ),
    );
  }
}
