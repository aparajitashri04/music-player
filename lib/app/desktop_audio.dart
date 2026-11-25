import 'dart:io';

import 'package:just_audio_media_kit/just_audio_media_kit.dart';

/// just_audio ships no Windows implementation, so on Windows playback is
/// provided by libmpv through `just_audio_media_kit`. It registers itself as
/// just_audio's platform implementation and must run before the first
/// `AudioPlayer` is created. Android and iOS keep just_audio's own native
/// players (the Android equalizer depends on them).
void initDesktopAudio() {
  if (Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized(
      windows: true,
      linux: false,
      macOS: false,
      android: false,
      iOS: false,
    );
  }
}
