import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum StorageAccess {
  /// The platform has no such permission (everything except Android).
  notRequired,
  granted,
  denied,
  permanentlyDenied,
}

abstract interface class StoragePermission {
  Future<StorageAccess> request();
  Future<void> openSettings();
}

/// Asks for audio access on Android. READ_MEDIA_AUDIO applies on Android 13+
/// and READ_EXTERNAL_STORAGE before that; requesting both makes the OS show
/// only the one that applies to this device.
class AndroidStoragePermission implements StoragePermission {
  @override
  Future<StorageAccess> request() async {
    final results = await [Permission.audio, Permission.storage].request();
    final statuses = results.values;
    if (statuses.any((s) => s.isGranted || s.isLimited)) {
      return StorageAccess.granted;
    }
    if (statuses.any((s) => s.isPermanentlyDenied)) {
      return StorageAccess.permanentlyDenied;
    }
    return StorageAccess.denied;
  }

  @override
  Future<void> openSettings() => openAppSettings();
}

class NoStoragePermission implements StoragePermission {
  @override
  Future<StorageAccess> request() async => StorageAccess.notRequired;

  @override
  Future<void> openSettings() async {}
}

final storagePermissionProvider = Provider<StoragePermission>(
  (ref) =>
      Platform.isAndroid ? AndroidStoragePermission() : NoStoragePermission(),
);
