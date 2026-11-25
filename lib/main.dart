import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/desktop_audio.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initDesktopAudio();
  runApp(const ProviderScope(child: MusicPlayApp()));
}
