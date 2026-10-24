import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../data/user_library.dart';
import '../tafsir/tafsir_sheet.dart';

Future<void> showAyahNoteEditor({
  required BuildContext context,
  required WidgetRef ref,
  required Ayah ayah,
}) async {
  final existing = ref.read(userLibraryProvider.notifier).noteFor(ayah.key);
  final saved = await showDialog<String>(
    context: context,
    builder: (context) => _AyahNoteDialog(
      ayahKey: ayah.key,
      initialText: existing,
    ),
  );
  if (saved == null) return;
  await ref.read(userLibraryProvider.notifier).setNote(ayah.key, saved);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        saved.trim().isEmpty ? 'Note cleared' : 'Note saved for ${ayah.key}',
      ),
    ),
  );
}

/// Owns the text controller so Save/Cancel never dispose it while still attached.
class _AyahNoteDialog extends StatefulWidget {
  const _AyahNoteDialog({
    required this.ayahKey,
    required this.initialText,
  });

  final String ayahKey;
  final String initialText;

  @override
  State<_AyahNoteDialog> createState() => _AyahNoteDialogState();
}

class _AyahNoteDialogState extends State<_AyahNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canClear = widget.initialText.trim().isNotEmpty;
    return AlertDialog(
      title: Text('Note · ${widget.ayahKey}'),
      content: TextField(
        controller: _controller,
        maxLines: 6,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Write a personal note for this ayah…',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (canClear)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Clear'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class AyahActionBar extends ConsumerWidget {
  const AyahActionBar({
    super.key,
    required this.ayah,
    required this.onClose,
  });

  final Ayah ayah;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(userLibraryProvider);
    final annotation = library[ayah.key];
    final bookmarked = annotation?.bookmarked ?? false;
    final hasNote = annotation?.hasNote ?? false;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 8,
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected ${ayah.key}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ActionChip(
                      icon: Icons.menu_book_outlined,
                      label: 'Tafsir',
                      onTap: () async {
                        await showTafsirSheet(context: context, ayah: ayah);
                      },
                    ),
                    _ActionChip(
                      icon: bookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      label: bookmarked ? 'Bookmarked' : 'Bookmark',
                      selected: bookmarked,
                      onTap: () async {
                        await ref
                            .read(userLibraryProvider.notifier)
                            .toggleBookmark(ayah.key);
                      },
                    ),
                    _ActionChip(
                      icon: hasNote
                          ? Icons.sticky_note_2
                          : Icons.sticky_note_2_outlined,
                      label: hasNote ? 'Edit note' : 'Note',
                      selected: hasNote,
                      onTap: () => showAyahNoteEditor(
                        context: context,
                        ref: ref,
                        ayah: ayah,
                      ),
                    ),
                    _ActionChip(
                      icon: Icons.copy_outlined,
                      label: 'Copy',
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: '${ayah.text}\n(${ayah.key})',
                          ),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ayah copied')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
        backgroundColor: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
      ),
    );
  }
}
