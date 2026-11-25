import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/library_folder.dart';

/// Asks for a folder name. Returns null if cancelled or left blank.
Future<String?> promptFolderName(
  BuildContext context, {
  String title = 'New folder',
  String confirmLabel = 'Create',
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _FolderNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initial: initial,
    ),
  );
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initial,
  });

  final String title;
  final String confirmLabel;
  final String initial;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Folder name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// What the user chose in [pickFolder].
sealed class FolderChoice {
  const FolderChoice();
}

class ChooseUnfiled extends FolderChoice {
  const ChooseUnfiled();
}

class ChooseFolder extends FolderChoice {
  const ChooseFolder(this.folder);
  final LibraryFolder folder;
}

class ChooseNewFolder extends FolderChoice {
  const ChooseNewFolder();
}

Future<FolderChoice?> pickFolder(
  BuildContext context,
  List<LibraryFolder> folders,
) {
  return showDialog<FolderChoice>(
    context: context,
    builder: (_) => SimpleDialog(
      backgroundColor: AppColors.card,
      title: const Text('Move to folder'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, const ChooseUnfiled()),
          child: const Text('No folder'),
        ),
        for (final folder in folders)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ChooseFolder(folder)),
            child: Text(folder.name),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, const ChooseNewFolder()),
          child: const Text('New folder…'),
        ),
      ],
    ),
  );
}
