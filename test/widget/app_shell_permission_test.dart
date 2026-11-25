import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_play/app/app_shell.dart';
import 'package:music_play/app/audio_backend.dart';
import 'package:music_play/app/storage_permission.dart';
import 'package:music_play/core/theme/app_theme.dart';
import 'package:music_play/features/library/application/library_notifier.dart';

import '../helpers/fakes.dart';

class FakePermission implements StoragePermission {
  FakePermission(this.result);

  final StorageAccess result;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<StorageAccess> request() async {
    requests++;
    return result;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

Future<void> pumpShell(WidgetTester tester, FakePermission permission) async {
  final container = ProviderContainer(
    overrides: [
      storagePermissionProvider.overrideWithValue(permission),
      playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
      equalizerEngineProvider.overrideWithValue(FakeEqualizerEngine()),
      libraryStoreProvider.overrideWithValue(MemoryLibraryStore()),
    ],
  );
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildAppTheme(), home: const AppShell()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('asks once on launch and stays quiet when granted', (
    tester,
  ) async {
    final permission = FakePermission(StorageAccess.granted);
    await pumpShell(tester, permission);
    expect(permission.requests, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('no message where the permission is not required', (
    tester,
  ) async {
    final permission = FakePermission(StorageAccess.notRequired);
    await pumpShell(tester, permission);
    expect(permission.requests, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('denied explains that the picker still works', (tester) async {
    await pumpShell(tester, FakePermission(StorageAccess.denied));
    expect(find.textContaining('Audio access was denied'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('permanently denied offers the app settings', (tester) async {
    final permission = FakePermission(StorageAccess.permanentlyDenied);
    await pumpShell(tester, permission);
    await tester.pump(const Duration(milliseconds: 500)); // snackbar slides in
    await tester.tap(find.text('Settings'));
    expect(permission.settingsOpened, 1);
  });
}
