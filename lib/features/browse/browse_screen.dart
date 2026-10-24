import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/quran_repository.dart';

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  Future<void> _openJuz(BuildContext context, WidgetRef ref, int juz) async {
    final ayah =
        await ref.read(quranRepositoryProvider).getFirstAyahInJuz(juz);
    if (!context.mounted || ayah == null) return;
    context.push('/surah/${ayah.surah}?ayah=${ayah.ayah}');
  }

  Future<void> _openPage(BuildContext context, WidgetRef ref, int page) async {
    final ayah =
        await ref.read(quranRepositoryProvider).getFirstAyahOnPage(page);
    if (!context.mounted || ayah == null) return;
    context.push('/surah/${ayah.surah}?ayah=${ayah.ayah}');
  }

  Future<void> _promptPage(BuildContext context, WidgetRef ref) async {
    final page = await showDialog<int>(
      context: context,
      builder: (context) => const _GoToPageDialog(),
    );
    if (page == null || !context.mounted) return;
    if (page < 1 || page > 604) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a page between 1 and 604')),
      );
      return;
    }
    await _openPage(context, ref, page);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Browse'),
          actions: [
            IconButton(
              tooltip: 'Jump to page number',
              onPressed: () => _promptPage(context, ref),
              icon: const Icon(Icons.pin_outlined),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Juz'),
              Tab(text: 'Pages'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView.builder(
              itemCount: 30,
              itemBuilder: (context, index) {
                final juz = index + 1;
                return ListTile(
                  leading: CircleAvatar(child: Text('$juz')),
                  title: Text('Juz $juz'),
                  subtitle: const Text('Open first ayah of this juz'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openJuz(context, ref, juz),
                );
              },
            ),
            GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: 604,
              itemBuilder: (context, index) {
                final page = index + 1;
                return Card(
                  child: InkWell(
                    onTap: () => _openPage(context, ref, page),
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: Text(
                        '$page',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns the text controller so Cancel never disposes it while still attached.
class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog();

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Go to page'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Madani page (1–604)',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) =>
            Navigator.pop(context, int.tryParse(_controller.text.trim())),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, int.tryParse(_controller.text.trim())),
          child: const Text('Open'),
        ),
      ],
    );
  }
}
