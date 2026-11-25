import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_shell.dart';

class MusicPlayApp extends StatelessWidget {
  const MusicPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Play',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}
