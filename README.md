# Music Play

A dark, calm music player for **Android** and **Windows**, built with Flutter.
Play the built-in sample tracks or your own audio files, organise them into folders, and (on Android) shape the sound with a real three-band equalizer.

> **Status:** `flutter analyze` is clean, all 67 automated tests pass, the Android debug APK and the Windows debug app build, and the app has been tested by hand on a device.

## Contents

1. [At a glance](#at-a-glance)
2. [What you can do](#what-you-can-do)
3. [Quick start](#quick-start)
4. [How to use it](#how-to-use-it)
5. [How it is built](#how-it-is-built)
6. [Playback, explained](#playback-explained)
7. [The equalizer, explained](#the-equalizer-explained)
8. [Windows, explained](#windows-explained)
9. [Your library and folders](#your-library-and-folders)
10. [Permissions](#permissions)
11. [Packages used](#packages-used)
12. [Decisions we made](#decisions-we-made)
13. [Testing and verification](#testing-and-verification)
14. [Known limitations](#known-limitations)
15. [Problems we hit and how we solved them](#problems-we-hit-and-how-we-solved-them)

---

## At a glance

| | Android | Windows |
| --- | --- | --- |
| Play the built-in tracks | Yes | Yes |
| Play files from your device | Yes (file picker) | Yes (file picker) |
| Play, pause, seek, next, previous | Yes | Yes |
| Title, artist, album, duration from file tags | Yes | No (uses the file name) |
| Equalizer (Low / Mid / High) | **Yes, native** | No. The screen says "Equalizer is available on Android only." |
| Folders, remove, multi-select, drag to move | Yes | Yes |
| Builds successfully | Yes (debug APK) | Yes (debug) |
| iOS | Not supported (the `ios/` folder was removed because it could not be tested) | |

## What you can do

**Listen**
- Play, pause, drag the seek bar, skip to the next or previous track.
- See the title, artist, elapsed time and total time.
- When a track ends, the next one starts. After the last track, playback stops and rewinds.
- Tap *Previous* more than 3 seconds into a song and it restarts the song instead of going back.

**Manage your library**
- Four sample tracks are built in (synthesised for this project, so there are no copyright issues).
- **Import** audio files from your device.
- **Folders:** create, rename, delete. Deleting a folder never deletes the tracks inside it.
- **Remove** tracks from the library, with an **Undo** button. Your audio files on disk are never touched.
- **Multi-select and drag:** long press a track, tap more tracks, then press-and-hold and drag them onto a folder.
- Everything is **saved**, so folders and imports are still there next time.

**Sound (Android only)**
- Three sliders: **Low**, **Mid**, **High**, each from -12 dB to +12 dB.
- An on/off switch and a **Reset** button.

**Look**
- Dark theme, flat design, no gradients, soft dusty-pink accent. Track "artwork" is a plain pink swatch.
- Phone layout (bottom bar + mini player) and wide layout (side rail + "Up next" list), switching at 820 px wide.

## Quick start

### What you need
- Flutter 3.44 or newer (Dart 3.12).
- **For Android:** Android SDK and JDK 17, plus a phone or emulator.
- **For Windows:** Windows 10 or 11, Visual Studio with the "Desktop development with C++" workload, and **Developer Mode** turned on (Flutter needs it for plugin links).

### Run it

```bash
flutter pub get

# Android (use your own device id from `flutter devices`)
flutter run -d <device-id>

# Windows
flutter run -d windows
```

> **Do not add `--flavor`.** This project has no flavors. If you see `Task 'assembleDevDebug' not found`, remove `--flavor dev` from your command or VS Code launch settings.

### Build it

```bash
flutter build apk --debug       # Android -> build/app/outputs/flutter-apk/app-debug.apk
flutter build windows --debug   # Windows -> build/windows/x64/runner/Debug/music_play.exe
```

The first Windows build downloads the audio engine (libmpv), so it needs internet.
The Android release build is signed with the debug key for now.

## How to use it

**Play a song:** open **Library**, tap a track.

**Import:** in **Library**, tap **Import** and pick one or more audio files.

**Make a folder:** tap the folder-plus icon at the top of **Library** and type a name.

**Move tracks into a folder (the fast way):**
1. **Long press** a track. It gets selected and the top bar changes to "1 selected".
2. **Tap** other tracks to add them.
3. **Press and hold** one of the selected tracks, then **drag** it onto a folder name. The folder lights up pink when you are over it.
4. Let go. All selected tracks move. Drop on **"Not in a folder"** to take them back out.

You can also use the **Move** button in the top bar, or the **⋮** menu on a single track.

**Remove tracks:** use the bin icon (selection) or **⋮ → Remove from library**. Tap **Undo** in the message at the bottom to bring them back.

**Equalizer (Android):** open **Equalizer**, wait for the sliders to wake up, then move them while a song plays.

## How it is built

The app is split into small "features". Screens only talk to *notifiers* (Riverpod state holders). Only the `data/` files talk to plugins or the phone.

```
Screens and widgets
   └─ Notifiers (Riverpod): Player, Library, Equalizer
        ├─ PlaybackEngine   (interface) ← JustAudioPlaybackEngine
        └─ EqualizerEngine  (interface) ← AndroidEqualizerEngine
                                          UnsupportedEqualizerEngine (Windows)
        both are created together over ONE audio player (audio_backend.dart)
```

**The key idea:** playing sound and changing the sound are two separate jobs with two separate interfaces, but they must share **one** audio player. That is how the equalizer is attached to the exact audio you hear. [`lib/app/audio_backend.dart`](lib/app/audio_backend.dart) creates that one player and hands out both interfaces.

**State management:** Riverpod, using plain `Notifier` classes (no code generation).
- `playerProvider`: current track, playing or not, loading, duration, error.
- `positionProvider`: the playback position, kept separate so the seek bar can update about 5 times a second without redrawing the whole screen.
- `libraryProvider`: tracks, folders, which track is in which folder.
- `equalizerProvider`: slider values and whether the equalizer is ready.

```
lib/
  main.dart                       starts the app (and the Windows audio engine)
  app/                            app shell + navigation, audio_backend (wiring),
                                  desktop_audio (Windows), storage_permission
  core/                           theme (colours), time formatting
  features/
    player/                       playback interface, just_audio engine, notifier, Now Playing screen
    library/                      tracks, folders, saving to disk, importing, Library screen
    equalizer/                    equalizer interface, Android engine, band mapping, screen
  shared/widgets/                 album art swatch, mini player, panel
android/.../MainActivity.kt       reads tags from audio files (title, artist, album, duration)
tools/generate_samples.py         makes the four sample WAV files
test/                             unit/ and widget/ tests, helpers/fakes.dart
```

## Playback, explained

- The **queue is the library list** in order. Folders only change how the list is *shown*, not the play order.
- Every time you pick a track, it gets a numbered **token**. If you tap quickly through several tracks, results from older taps are thrown away, so you always end on the last one you chose.
- The first track is **loaded paused** when the app opens. Reason: the Android equalizer can only be created once the player has something loaded.
- The play/pause button follows the **real player state**, not a guess.
- **Errors:** a missing or unreadable file shows a message and a snackbar. Press play to retry. The app does not crash.
- **Removing the track that is playing** moves on to its neighbour (and keeps playing if it was playing). Removing everything clears the player.

## The equalizer, explained

**It is a real equalizer.** On Android it uses the phone's built-in `android.media.audiofx.Equalizer`, reached through the `just_audio` package and attached to the same audio session as the player. Moving a slider sends the gain straight to the phone's audio system. It is not just a picture.

**Phones have different numbers of bands** (commonly 5, at frequencies like 60, 230, 910, 3600 and 14000 Hz). So the three sliders are matched by **frequency range**, not by band number:

| Slider | Controls every phone band that sits at… |
| --- | --- |
| Low | 250 Hz or lower |
| Mid | above 250 Hz up to 4 kHz |
| High | above 4 kHz |

Example on a typical 5-band phone: Low drives 2 bands, Mid drives 2, High drives 1. If a range has no band at all, that slider borrows the nearest band (aiming at 100 Hz, 1 kHz or 8 kHz).

**Other details**
- **Gain limits:** ±12 dB, and never beyond what the phone says it supports (a ±6 dB phone gets ±6 dB sliders). Values are in decibels all the way to the phone, so no conversion is needed.
- **Reset** sets all three sliders **and** every real phone band back to 0 dB.
- **Switch off** bypasses the effect but keeps your slider positions.
- **Changing track:** gains are re-applied after every load, so what you hear always matches the sliders.
- **Timing:** the phone only exposes the equalizer after a track has loaded. If it isn't ready within 6 seconds, the screen shows a message with **Retry**, and it also retries by itself after the next track loads.
- **Errors:** if the phone refuses something, you see an error with Retry instead of silently wrong sliders.

**Why no equalizer on Windows?** The Android equalizer is a feature of the Android system and does not exist on Windows. On Windows the app plays audio with libmpv (see below), and the plugin that wraps it has no equalizer and keeps the player hidden from the app. A Windows equalizer is *possible in principle*: libmpv has audio filters such as `equalizer`, which could be set through media_kit's `NativePlayer.setProperty('af', ...)` behind the same `EqualizerEngine` interface. It would need either a direct media_kit playback engine or a patched plugin, and we have **not** confirmed that the libmpv build we bundle includes those filters. So we left it out on purpose, and the screen says so clearly instead of showing fake sliders.

## Windows, explained

The `just_audio` package has no Windows support by itself. We add **`just_audio_media_kit`**, which plays audio through libmpv.

- It is switched on in [`lib/app/desktop_audio.dart`](lib/app/desktop_audio.dart), called from `main()` **before** any player exists. It only does anything on Windows, so Android keeps its native player (which the equalizer needs).
- **Bundled tracks:** `just_audio` reads the asset from the app, saves it to a temporary file, and gives libmpv that file's path. libmpv never needs to understand Flutter assets.
- **Imported files:** passed as normal file addresses (`file:///C:/…`).
- The audio-focus helper (`audio_session`) is skipped on Windows.

## Your library and folders

- Saved as one small JSON file called `library.json` in the app's support folder (found with `path_provider`). **No database.**
- What is saved: imported tracks (location, title, artist, album, duration), your folders, which track is in which folder, and which sample tracks you removed.
- It is written to a temporary file first, then swapped in, so a crash can't corrupt it. Bad entries in the file are skipped instead of breaking the whole library.
- **Android caveat:** the picker may give a temporary `content://` address. After a restart, such a track can show "missing or unreadable" until you import it again.

## Permissions

On Android the app asks for **audio access** as soon as it opens (`READ_MEDIA_AUDIO` on Android 13 and newer, `READ_EXTERNAL_STORAGE` on Android 12 and older; both are in `AndroidManifest.xml`).

- If you say no, a message explains that you can still import with the picker. If Android will not ask again, the message has a **Settings** button.
- **Honest note:** the picker already works without this permission, so granting it does not let you import anything extra. It is asked for because we chose to.
- Windows never asks.

## Packages used

| Package | What it does here |
| --- | --- |
| `flutter_riverpod` 3 | State management |
| `just_audio` 0.10 | Playback, plus the Android equalizer |
| `just_audio_media_kit` + `media_kit_libs_windows_audio` | Makes `just_audio` work on Windows (libmpv) |
| `audio_session` | Audio focus on Android (pauses nicely for calls etc.) |
| `file_picker` 13 | System file picker for importing |
| `permission_handler` 12 | Asks for audio access on Android. Version 13 needs a newer Android SDK than this project's Android Gradle Plugin supports, so we use 12. |
| `path_provider`, `path` | Finding the save folder and working with file names |
| `mocktail`, `flutter_lints` (dev) | Testing and code style |

Tags (title, artist, album, duration) on Android come from a small piece of Kotlin in `MainActivity.kt` using Android's `MediaMetadataRetriever`. The popular `metadata_god` package was skipped because it needs a Rust toolchain to build.

## Decisions we made

| Decision | Why |
| --- | --- |
| Folders are **inside the app** | Simple, safe, works the same on both platforms. They never move or change real files. |
| "Remove" only removes from the **library** | Your files are yours. Nothing is ever deleted from disk. Undo is available. |
| Save with a **JSON file**, not a database | Small data, no extra setup. |
| **No gradients**, flat pink swatches for artwork | Cleaner, less "template" look. Embedded cover images are not shown. |
| Equalizer is **Android only** | Needs the Android audio effect. Windows has no equalizer, so the UI says so honestly. |
| **iOS removed** | It could not be built or tested, and we don't claim what we can't test. |
| Playback and equalizer are **separate interfaces** over one player | Keeps screens simple and leaves room to add another platform later. |

## Testing and verification

```bash
flutter analyze --no-pub
flutter test --no-pub
```

**Checked and passing**

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues |
| `flutter test --no-pub` | 67 tests pass |
| `flutter build apk --debug` | Builds |
| `flutter build windows --debug` | Builds |

The tests cover: time formatting, track import fallbacks, equalizer band mapping and gain limits, equalizer reset / re-apply / failure handling, play-pause-next-previous-completion-errors, rapid track switching, seeking limits, removing and undoing tracks, folders, saving and loading, removing the playing track, multi-select and drag to a folder, the Android-only equalizer message, and the permission message.

**Manual check: Android**
1. `flutter run -d <device-id>`. Allow or deny the audio permission and confirm the app still works either way.
2. Open **Equalizer** and wait until the sliders are active.
3. In **Library**, play *Neon Rain*. Drag **High** to +12 dB: it should get brighter. To -12 dB: duller.
4. Play *Low Tide*. Drag **Low** to +12 dB: fuller bass. To -12 dB: thinner.
5. Switch the equalizer off: the sound returns to normal, sliders stay. Switch on: it comes back.
6. Press **Reset**: sliders at 0 and the sound matches the "off" sound.
7. Set a non-zero EQ, then skip tracks: the character should stay.
8. **Import** an `.mp3` or `.m4a`: title, artist and duration should appear. Play it.
9. Tap next and previous quickly: it should end on the last track you chose, with no crash.

**Manual check: Windows**
1. `flutter run -d windows`. Play a sample track, pause, seek, next, previous.
2. Import a local `.mp3` or `.wav` and play it.
3. Let a track finish: the next should start.
4. Open **Equalizer**: it should show only the Android-only message.
5. Make a folder, long-press select two tracks, drag them onto the folder.
6. Close and reopen: folders and imports should still be there.

## Known limitations

- No equalizer on Windows. No iOS.
- On Windows, tracks have no tags: the title comes from the file name.
- Android `content://` imports may need re-importing after a restart.
- Removed sample tracks can only be restored with **Undo** right after removing (no "restore all").
- Embedded cover images are intentionally not shown.
- While dragging, the list does not auto-scroll near its edges.
- Sample tracks are simple synthesised loops, not studio recordings.
- The Android release build uses the debug signing key.

## Problems we hit and how we solved them

- **Windows had no sound at all.** `just_audio` has no Windows backend, so every track failed to load. Fixed by adding `just_audio_media_kit`.
- **Equalizer not ready at start.** Android only creates it after a track loads. Fixed by loading the first track paused, plus a retry path.
- **Tags on Android.** The Rust-based tag library was too heavy, so a small Kotlin bridge reads them instead.
- **`content://` addresses.** The newer file picker may return addresses instead of file paths, so tracks are stored by address.
- **A newer permission plugin broke the Android build** (needs a newer SDK). Using version 12 fixed it.
- **Wrong `--flavor` command.** See [Quick start](#quick-start): this project has no flavors.
- **Royalty-free audio.** Instead of downloading, `tools/generate_samples.py` synthesises the four sample tracks. To regenerate them, install Python with `numpy` and run `python tools/generate_samples.py`.
