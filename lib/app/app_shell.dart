import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/equalizer/presentation/equalizer_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/player/application/player_notifier.dart';
import '../features/player/presentation/now_playing_screen.dart';
import '../shared/widgets/mini_player.dart';
import 'storage_permission.dart';

const double _wideBreakpoint = 820;

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination(
    'Now Playing',
    Icons.graphic_eq_rounded,
    Icons.graphic_eq_rounded,
  ),
  _Destination(
    'Library',
    Icons.library_music_outlined,
    Icons.library_music_rounded,
  ),
  _Destination('Equalizer', Icons.tune_rounded, Icons.tune_rounded),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askForAudioAccess());
  }

  /// Asked once per launch, as soon as the first frame is up. Denying it never
  /// blocks the app: importing goes through the system picker, which needs no
  /// permission.
  Future<void> _askForAudioAccess() async {
    final permission = ref.read(storagePermissionProvider);
    try {
      final access = await permission.request();
      if (!mounted) return;
      if (access != StorageAccess.denied &&
          access != StorageAccess.permanentlyDenied) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'Audio access was denied. You can still import files with the picker.',
            ),
            action: access == StorageAccess.permanentlyDenied
                ? SnackBarAction(
                    label: 'Settings',
                    onPressed: permission.openSettings,
                  )
                : null,
          ),
        );
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'music_play',
          context: ErrorDescription('while requesting audio access'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playerProvider.select((s) => s.error), (_, error) {
      if (error == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        final body = IndexedStack(
          index: _index,
          children: [
            const NowPlayingScreen(),
            LibraryScreen(onTrackSelected: wide ? null : () => _go(0)),
            const EqualizerScreen(),
          ],
        );
        final miniPlayer = _index == 0
            ? const SizedBox.shrink()
            : MiniPlayer(onOpen: () => _go(0));

        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: constraints.maxWidth >= 1100,
                  selectedIndex: _index,
                  onDestinationSelected: _go,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: _Brand(),
                  ),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: body),
                      miniPlayer,
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              miniPlayer,
              NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _go,
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(
                        d.selectedIcon,
                        color: AppColors.accent,
                      ),
                      label: d.label,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: const Icon(Icons.music_note_rounded, color: AppColors.onAccent),
    );
  }
}
