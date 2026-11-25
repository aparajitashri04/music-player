# Music Play

A dark, premium Flutter music player for Android and Windows, with a real three-band native equalizer on Android.

> **Status.** Android and Windows playback and the Android native equalizer are implemented. The Windows build compiles; **no audio has been played back on either platform by the author of this change** (see [Verification results](#verification-results)). The `ios/` platform folder has been removed; iOS is not supported.

## Features

- Play / pause, seek, previous / next, track title and artist, elapsed / total time, live progress.
- Track completion advances to the next track; the last track stops and rewinds.
- Rapid track switching is safe: stale loads are discarded.
- Library with 4 bundled sample tracks and import of local audio files (system picker, no storage permissions).
- Remove tracks from the library (with Undo). This never deletes the audio file from the device; bundled samples can be removed too.
- In-app folders: create, rename, delete, and move tracks between them. Deleting a folder keeps its tracks. Folders only group the library view; the playback queue stays in library order.
- Multi-select: long press a track to select it, tap more to add, then press and hold a selected track and drag it onto a folder header (or use the Move / Remove buttons in the selection bar). Dragging onto "Not in a folder" takes tracks out of a folder.
- The library (imported tracks, folders, removals) is saved to a small JSON file in the app support directory (`library.json`), no database.
- Flat, solid-colour UI: a dark theme with a muted dusty-pink accent and no gradients. Track artwork is a solid pink swatch chosen from the track id, not cover images.
- Tags (title, artist, album, duration) read natively on Android with `MediaMetadataRetriever`; the file name is used when tags are missing.
- Missing or unreadable files show an inline error and a snackbar instead of crashing; pressing play retries.
- Three-band equalizer (Low / Mid / High, −12 dB to +12 dB) applied by Android's `android.media.audiofx.Equalizer`, with enable/bypass switch and Reset.
- Windows playback through libmpv (`just_audio_media_kit`) for bundled assets and imported local files.
- Responsive layout: bottom navigation + mini player on phones, navigation rail and two-pane Now Playing on wide windows.

## Screenshots

None yet. Screenshots will be added after the app has been run on a device; none are included rather than showing mock-ups.

## Architecture

Feature-first, with playback and equalizing as **separate interfaces**. The UI talks only to Riverpod notifiers; only the `data/` classes touch native or plugin APIs.

```
UI (screens/widgets)
  └─ Riverpod notifiers (PlayerNotifier, EqualizerNotifier, LibraryNotifier)
       ├─ PlaybackEngine (interface)  ←  JustAudioPlaybackEngine
       └─ EqualizerEngine (interface) ←  AndroidEqualizerEngine | UnsupportedEqualizerEngine
                         both created together by AudioBackend over ONE AudioPlayer
```

`lib/app/desktop_audio.dart` registers the Windows playback backend at startup (called from `main()` before any player exists). `lib/app/audio_backend.dart` is the composition root. It creates exactly one `AudioPlayer` (held by a single Riverpod `Provider`, disposed with it) and, on Android, attaches an `AndroidEqualizer` to its `AudioPipeline`. Both engines are exposed through their own providers.

### Folder structure

```
lib/
  main.dart
  app/                    app.dart, app_shell.dart (navigation), audio_backend.dart (composition root)
  core/                   theme/app_theme.dart, utils/duration_format.dart
  features/
    player/               domain/playback_engine.dart, data/just_audio_playback_engine.dart,
                          application/player_notifier.dart, presentation/…
    library/              domain/track.dart, data/{bundled_tracks,metadata_reader,track_importer}.dart,
                          application/library_notifier.dart, presentation/…
    equalizer/            domain/{equalizer_engine,eq_band_mapping,eq_state}.dart,
                          data/{android,unsupported}_equalizer_engine.dart,
                          application/equalizer_notifier.dart, presentation/…
  shared/widgets/         album_art.dart, panel.dart, mini_player.dart
android/…/MainActivity.kt metadata channel (MediaMetadataRetriever)
assets/                   generated sample audio
tools/generate_samples.py generator for the sample assets
test/                     unit/, widget/, helpers/fakes.dart
```

## Package choices

| Package | Why |
| --- | --- |
| `just_audio` 0.10 | Playback, and `AndroidEqualizer` / `AudioPipeline` for native DSP |
| `just_audio_media_kit` + `media_kit_libs_windows_audio` | just_audio has no Windows implementation; these supply libmpv-based playback on Windows only |
| `permission_handler` 12 | Asks for audio access on Android at launch (v13 needs compileSdk 37, which this project's Android Gradle Plugin does not support) |
| `audio_session` | Audio-focus / interruption configuration (`AudioSessionConfiguration.music()`), applied on Android only; failures are reported, not hidden |
| `flutter_riverpod` 3 | State management; `Notifier` providers, no code generation |
| `file_picker` 13 | System audio picker (Storage Access Framework on Android, so no storage permission) |
| `path`, `path_provider` | File-name handling |
| `mocktail` (dev) | Available for tests; current tests use hand-written fakes |

`metadata_god` was evaluated and rejected: it needs a Rust toolchain to build, which is absent here and would be an extra setup burden. Android tags are read through a ~40-line Kotlin channel instead.

## Playback implementation

`PlaybackEngine` plays one source at a time and exposes position, duration, playing and phase streams. Queue logic lives in `PlayerNotifier`:

- The queue is the library list; the current index is derived from the current track, so imports never invalidate it.
- Every load takes a token. If a newer selection arrives, the older result is dropped (just_audio also aborts the older load with `PlayerInterruptedException`, which is treated as non-error).
- The UI's play state comes from the engine's `playingStream`, not from optimistic local flags.
- The first track is preloaded paused at launch so the native audio session (and equalizer) exists before the user presses play.
- Position is a separate `StreamProvider`, so the seek bar updates ~5×/s without rebuilding the rest of the UI.

## Equalizer implementation and frequency mapping

Android devices expose 5 or more bands at hardware-specific centre frequencies, so three sliders are mapped by **frequency range**, not by fixed band index:

| Slider | Device bands driven |
| --- | --- |
| Low | centre frequency ≤ 250 Hz |
| Mid | 250 Hz < centre ≤ 4 kHz |
| High | centre > 4 kHz |

Each device band belongs to exactly one slider (for a typical 5-band device — 60, 230, 910, 3 600, 14 000 Hz — Low drives 2 bands, Mid 2, High 1). If a range contains no band, the slider borrows the band nearest to its target (100 Hz / 1 kHz / 8 kHz) on a log scale. Logic: [`eq_band_mapping.dart`](lib/features/equalizer/domain/eq_band_mapping.dart).

- Gain is clamped to ±12 dB **and** to the device's reported min/max (e.g. a ±6 dB device gets a ±6 dB slider).
- The effect is disabled by default in just_audio; the app enables it explicitly.
- `AndroidEqualizer.parameters` only resolves once the player has loaded a source, hence the paused preload. If it doesn't resolve within 6 s the screen shows a message with Retry, and initialisation is retried automatically after the next track loads.
- Gains are re-applied after every track load, so EQ state can't drift from the sliders.
- Reset sets all three sliders and every mapped device band to 0 dB.
- Any native failure surfaces as an error banner instead of silently leaving the sliders out of sync.

On non-Android platforms `UnsupportedEqualizerEngine` is used: the Equalizer screen shows only "Equalizer is available on Android only." (no sliders, curve, switch or Reset). Another platform's engine would implement `EqualizerEngine` without touching the UI or `PlaybackEngine`.

## State management

Riverpod `NotifierProvider`s only: `playerProvider`, `libraryProvider`, `equalizerProvider`, plus `positionProvider` (stream) and the engine providers. Tests override the engine providers with fakes.

## Platform differences

| | Android | Windows |
| --- | --- | --- |
| Playback | Implemented (just_audio / ExoPlayer) | Implemented (just_audio_media_kit / libmpv); builds, not heard |
| Import | Implemented | Implemented (file paths via `file://` URIs); not run |
| Tags | Native `MediaMetadataRetriever` | File-name fallback only |
| Equalizer | Implemented (native) | None; UI says "Android only" |

**Windows asset loading:** `AudioSource.asset` is resolved by just_audio itself: it reads the asset with `rootBundle`, writes it to a temp cache file, and hands that `file://` path to the platform player, so libmpv never needs to understand Flutter assets. Imported files are passed as `Uri.file(path)`.

**iOS:** not supported. The `ios/` folder was removed because it could not be built or tested; `flutter create --platforms=ios .` would restore it.

## Challenges encountered

- **Latest package majors.** just_audio 0.10, Riverpod 3 and file_picker 13 differ from older tutorials (e.g. `FilePicker.pickFiles` is now static and multi-select by default).
- **`metadata_god` needs Rust.** Replaced with a native Kotlin channel.
- **Equalizer isn't available before a source loads.** just_audio's `AndroidEqualizer.parameters` completes only after the player platform is created; handled via the paused preload and a retry path.
- **`content://` URIs.** file_picker 13 may return URIs without a file path on Android, so tracks and the metadata channel are URI-based.
- **No royalty-free audio downloads in the repo.** The sample tracks are synthesized by `tools/generate_samples.py`.

## Setup

Requirements: Flutter 3.44+ (Dart 3.12), Android SDK, JDK 17.

```bash
flutter pub get
```

Regenerate sample assets (optional; needs Python with `numpy`):

```bash
python tools/generate_samples.py
```

### Android

```bash
flutter run -d <android-device-id>      # debug on a device/emulator
flutter build apk --debug               # debug APK
flutter build apk --release             # release APK (signed with the debug key for now)
```

### Windows

Requirements: Windows 10+, Visual Studio with the "Desktop development with C++" workload, Developer Mode enabled (for plugin symlinks).

```bash
flutter run -d windows
flutter build windows --debug
```

The first build downloads libmpv through `media_kit_libs_windows_audio`, so it needs network access.

## Tests and verification

```bash
dart format lib test
flutter analyze
flutter test
```

Automated tests (fakes for both engines) cover: duration formatting, track model and import fallbacks, EQ band mapping and gain clamping, EQ reset / re-apply after track change / failure handling, player selection and transitions (next/previous/wrap/completion/error/rapid switching/seek clamping), playback controls, EQ sliders and the library tap-to-play flow, library removal/undo, folders, persistence encoding, and removing the playing track.

> Automated tests use fake engines, so they **cannot** prove audible equalization. Verify it manually on a device:

### Android manual verification (audible EQ)

1. `flutter run -d <android-device>` and open **Equalizer**; wait for the sliders to become active (the status banner disappears).
2. Go to **Library**, tap *Neon Rain* (bright, buzzy timbre) and start playback.
3. On **Equalizer**, drag **High** to +12 dB: the sound must get noticeably brighter/harsher. Drag **High** to −12 dB: it must get duller.
4. Drag **Low** to +12 dB on *Low Tide*: bass must get fuller; −12 dB: thinner.
5. Toggle the switch off: sound returns to the original while the sliders keep their values; on again re-applies.
6. Press **Reset**: all sliders at 0 dB and the sound matches the bypassed sound.
7. With a non-zero setting, skip to another track: the character must persist.
8. **Import** an `.mp3`/`.m4a` from the device: title/artist/duration should appear; tap it to play.
9. Select a track and rapidly tap next/previous: playback must end on the last requested track with no crash.

## Verification results

Actually performed (Windows 11 dev machine, Flutter 3.44.2):

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: all 67 tests pass (fake engines; they do not prove audio output).
- `flutter build windows --debug`: succeeded (`music_play.exe`), with a harmless CMake policy warning from `media_kit_libs_windows_audio`.

- `flutter build apk --debug`: succeeded (`app-debug.apk`).

**Not performed:** running the app on a device or emulator, any audible playback, equalizer audibility, or the permission dialog. Follow the manual checklists to verify.

## Android audio permission

On launch the Android app asks for audio access (`READ_MEDIA_AUDIO` on Android 13+, `READ_EXTERNAL_STORAGE` up to Android 12; declared in `AndroidManifest.xml`). Denying it shows a message and, if the OS will no longer ask, a Settings shortcut. **It does not gate anything:** Import uses the system file picker, which grants access to the files you choose without this permission, so the permission does not widen what can be imported. Other platforms never request it.

## Why there is no equalizer on desktop

The Android equalizer is `android.media.audiofx.Equalizer`, reached through just_audio's `AndroidEqualizer`; it exists only on Android. Windows playback runs on libmpv via `just_audio_media_kit`, which has no equalizer and keeps its media_kit `Player` private, so the app cannot reach mpv's audio filters. A desktop EQ is feasible in principle (mpv's `equalizer`/`superequalizer` filters set through `NativePlayer.setProperty('af', …)`, behind the existing `EqualizerEngine` interface) but would need either a direct media_kit `PlaybackEngine` or a forked plugin, and it is unverified whether the bundled libmpv ships those filters. It is intentionally not implemented; the screen says so.

## Known limitations

- Windows playback and import compile but have **not** been run with real audio.
- There is no equalizer on Windows.
- The saved library keeps file locations only. On Android, `content://` access may not survive a restart, so such a track can show "missing or unreadable" until re-imported.
- Removed bundled samples have no "restore all" action (only Undo right after removing).
- Embedded cover images are intentionally not displayed.
- Tags for imported files are read only on Android; on Windows the title comes from the file name and duration from the player.
- The equalizer's effect depends on the device's `Equalizer` implementation; some devices expose few bands or limited range.
- Sample tracks are simple synthesized loops, not studio recordings.
- Android release builds are signed with the debug key.
