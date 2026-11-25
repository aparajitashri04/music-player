import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/panel.dart';
import '../../player/application/player_notifier.dart';
import '../application/library_notifier.dart';
import '../domain/library_folder.dart';
import '../domain/track.dart';
import 'widgets/folder_dialogs.dart';
import 'widgets/track_tile.dart';

/// Track ids being dragged between folders.
typedef _DragPayload = List<String>;

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.onTrackSelected});

  /// Lets the shell jump to Now Playing after a pick on compact layouts.
  final VoidCallback? onTrackSelected;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final Set<String> _collapsed = {};

  /// Ids chosen with long press / tap. Selection mode is on while non-empty.
  final Set<String> _selected = {};

  LibraryNotifier get _library => ref.read(libraryProvider.notifier);

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final outcome = await _library.importFiles();
      if (outcome.isEmpty) return;
      final parts = <String>[
        if (outcome.added > 0)
          'Imported ${outcome.added} ${outcome.added == 1 ? 'track' : 'tracks'}',
        if (outcome.duplicates > 0) '${outcome.duplicates} already in library',
        if (outcome.skipped > 0) '${outcome.skipped} could not be read',
      ];
      messenger.showSnackBar(SnackBar(content: Text(parts.join(' · '))));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the file picker.')),
      );
    }
  }

  Future<void> _newFolder() async {
    final name = await promptFolderName(context);
    if (name != null) _library.createFolder(name);
  }

  Future<void> _renameFolder(LibraryFolder folder) async {
    final name = await promptFolderName(
      context,
      title: 'Rename folder',
      confirmLabel: 'Rename',
      initial: folder.name,
    );
    if (name != null) _library.renameFolder(folder.id, name);
  }

  void _deleteFolder(LibraryFolder folder) {
    _library.deleteFolder(folder.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted folder "${folder.name}". Tracks were kept.'),
        ),
      );
  }

  /// Moves [ids] (or the whole selection) via the folder picker dialog.
  Future<void> _moveWithDialog(List<String> ids) async {
    final folders = ref.read(libraryProvider).folders;
    final choice = await pickFolder(context, folders);
    if (choice == null || !mounted) return;
    switch (choice) {
      case ChooseUnfiled():
        _library.moveTracksToFolder(ids, null);
      case ChooseFolder(:final folder):
        _library.moveTracksToFolder(ids, folder.id);
      case ChooseNewFolder():
        final name = await promptFolderName(context);
        if (name == null) return;
        final created = _library.createFolder(name);
        if (created != null) _library.moveTracksToFolder(ids, created.id);
    }
    if (mounted) setState(_selected.clear);
  }

  void _removeAll(List<Track> tracks) {
    final removed = [for (final t in tracks) ?_library.removeTrack(t.id)];
    if (removed.isEmpty) return;
    setState(_selected.clear);
    final label = removed.length == 1
        ? 'Removed "${removed.first.track.title}" from the library'
        : 'Removed ${removed.length} tracks from the library';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(label),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // Reinsert from the lowest index up so positions line up.
              final ordered = [...removed]
                ..sort((a, b) => a.index.compareTo(b.index));
              for (final r in ordered) {
                _library.restoreTrack(r);
              }
            },
          ),
        ),
      );
  }

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  void _dropOnFolder(_DragPayload ids, String? folderId) {
    _library.moveTracksToFolder(ids, folderId);
    setState(_selected.clear);
    final count = ids.length;
    final folders = ref.read(libraryProvider).folders;
    final target = folderId == null
        ? 'out of their folder'
        : 'to "${folders.firstWhere((f) => f.id == folderId).name}"';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Moved $count ${count == 1 ? 'track' : 'tracks'} $target',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final player = ref.watch(playerProvider);
    final theme = Theme.of(context);

    // Drop selections of tracks that no longer exist (e.g. removed elsewhere).
    final liveIds = library.tracks.map((t) => t.id).toSet();
    _selected.removeWhere((id) => !liveIds.contains(id));
    final selecting = _selected.isNotEmpty;
    final selectedTracks = [
      for (final t in library.tracks)
        if (_selected.contains(t.id)) t,
    ];

    void select(Track track) {
      ref.read(playerProvider.notifier).selectTrack(track);
      widget.onTrackSelected?.call();
    }

    Widget tile(Track track) {
      final isSelected = _selected.contains(track.id);
      final item = TrackTile(
        key: ValueKey(track.id),
        track: track,
        isCurrent: player.current == track,
        isPlaying: player.current == track && player.isPlaying,
        selectionMode: selecting,
        selected: isSelected,
        onTap: selecting ? () => _toggle(track.id) : () => select(track),
        onLongPress: selecting ? null : () => _toggle(track.id),
        onMove: () => _moveWithDialog([track.id]),
        onRemove: () => _removeAll([track]),
      );
      if (!isSelected) return item;
      // A selected track can be picked up (press and hold, then drag) to carry
      // the whole selection onto a folder.
      final ids = [for (final t in selectedTracks) t.id];
      return LongPressDraggable<_DragPayload>(
        data: ids,
        delay: const Duration(milliseconds: 250),
        feedback: Material(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              ids.length == 1 ? track.title : '${ids.length} tracks',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.onAccent,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: item),
        child: item,
      );
    }

    Widget sectionHeader(
      String title, {
      String? folderId,
      LibraryFolder? folder,
      required int count,
      required bool dropTarget,
    }) {
      final collapsed = folderId != null && _collapsed.contains(folderId);
      Widget header(bool hovering) => Container(
        margin: const EdgeInsets.only(top: AppSpacing.md),
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        decoration: BoxDecoration(
          color: hovering
              ? AppColors.accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(
            color: hovering ? AppColors.accent : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.control),
                onTap: folderId == null
                    ? null
                    : () => setState(
                        () => collapsed
                            ? _collapsed.remove(folderId)
                            : _collapsed.add(folderId),
                      ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      if (folderId != null) ...[
                        Icon(
                          collapsed
                              ? Icons.chevron_right_rounded
                              : Icons.expand_more_rounded,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(
                          Icons.folder_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text('$count', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ),
            if (folder != null)
              PopupMenuButton<String>(
                tooltip: 'Folder options',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                color: AppColors.card,
                onSelected: (value) {
                  if (value == 'rename') _renameFolder(folder);
                  if (value == 'delete') _deleteFolder(folder);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete folder (keeps tracks)'),
                  ),
                ],
              ),
          ],
        ),
      );

      if (!dropTarget) return header(false);
      return DragTarget<_DragPayload>(
        onAcceptWithDetails: (details) => _dropOnFolder(details.data, folderId),
        builder: (context, candidates, _) => header(candidates.isNotEmpty),
      );
    }

    final unfiled = library.unfiled;
    final hasFolders = library.folders.isNotEmpty;
    final children = <Widget>[
      for (final folder in library.folders) ...[
        sectionHeader(
          folder.name,
          folderId: folder.id,
          folder: folder,
          count: library.inFolder(folder.id).length,
          dropTarget: true,
        ),
        if (!_collapsed.contains(folder.id))
          if (library.inFolder(folder.id).isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                'Empty. Drag tracks here, or use a track\'s menu.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            for (final track in library.inFolder(folder.id)) tile(track),
      ],
      if (unfiled.isNotEmpty) ...[
        sectionHeader(
          hasFolders ? 'Not in a folder' : 'All tracks',
          count: unfiled.length,
          dropTarget: hasFolders,
        ),
        for (final track in unfiled) tile(track),
      ],
      if (library.tracks.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Panel(
            child: Column(
              children: [
                const Icon(
                  Icons.folder_open_rounded,
                  size: 36,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your library is empty',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Import audio files from this device to start listening.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
    ];

    final Widget topBar = selecting
        ? Row(
            children: [
              IconButton(
                tooltip: 'Cancel selection',
                onPressed: () => setState(_selected.clear),
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: Text(
                  '${_selected.length} selected',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Move to folder',
                onPressed: () =>
                    _moveWithDialog([for (final t in selectedTracks) t.id]),
                icon: const Icon(Icons.drive_file_move_outlined),
              ),
              IconButton(
                tooltip: 'Remove from library',
                onPressed: () => _removeAll(selectedTracks),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Library', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${library.tracks.length} tracks',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'New folder',
                onPressed: _newFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: library.isImporting ? null : _import,
                icon: library.isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: const Text('Import'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                ),
              ),
            ],
          );

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: topBar,
                ),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
