import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback.dart';
import '../../core/preferences.dart';
import '../../data/models/models.dart';
import '../../data/repositories/quran_repository.dart';
import '../../data/user_library.dart';
import '../reader/ayah_actions.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(userLibraryProvider);
    final favoriteIds = ref.watch(favoriteSurahsProvider);
    final notifier = ref.read(userLibraryProvider.notifier);
    final ayahBookmarks = notifier.bookmarks;
    final notes = notifier.notes;
    final surahsAsync = ref.watch(surahsProvider);

    final favoriteSurahs = surahsAsync.maybeWhen(
      data: (surahs) {
        final byNumber = {for (final s in surahs) s.number: s};
        return favoriteIds
            .map((n) => byNumber[n])
            .whereType<Surah>()
            .toList()
          ..sort((a, b) => a.number.compareTo(b.number));
      },
      orElse: () => <Surah>[],
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bookmarks & notes'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Surah (${favoriteSurahs.length})'),
              Tab(text: 'Ayah (${ayahBookmarks.length})'),
              Tab(text: 'Notes (${notes.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SurahFavoritesList(surahs: favoriteSurahs),
            _AnnotationList(
              emptyLabel:
                  'No bookmarked ayahs yet.\nTap an ayah → Bookmark.',
              items: ayahBookmarks,
              showBookmarkActions: true,
            ),
            _AnnotationList(
              emptyLabel: 'No notes yet.\nTap an ayah → Note.',
              items: notes,
              showBookmarkActions: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahFavoritesList extends ConsumerWidget {
  const _SurahFavoritesList({required this.surahs});

  final List<Surah> surahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (surahs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No bookmarked surahs yet.\nTap the star on a surah to save it here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: surahs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final surah = surahs[index];
        return ListTile(
          leading: CircleAvatar(child: Text('${surah.number}')),
          title: Text(
            surah.nameAr,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'UthmanicHafs', fontSize: 22),
          ),
          subtitle: Text('${surah.nameEn} · ${surah.ayahCount} ayahs'),
          trailing: IconButton(
            tooltip: 'Remove bookmark',
            icon: Icon(Icons.star_rounded, color: Colors.amber.shade700),
            onPressed: () async {
              await ref
                  .read(favoriteSurahsProvider.notifier)
                  .toggle(surah.number);
              if (!context.mounted) return;
              showAppToast(
                context,
                '${surah.nameEn} removed from bookmarks',
              );
            },
          ),
          onTap: () => context.push('/surah/${surah.number}'),
        );
      },
    );
  }
}

class _AnnotationList extends ConsumerWidget {
  const _AnnotationList({
    required this.emptyLabel,
    required this.items,
    required this.showBookmarkActions,
  });

  final String emptyLabel;
  final List<AyahAnnotation> items;
  final bool showBookmarkActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyLabel, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final parts = item.ayahKey.split(':');
        final surah = int.parse(parts[0]);
        final ayah = int.parse(parts[1]);

        return FutureBuilder(
          future: ref.read(quranRepositoryProvider).getAyah(surah, ayah),
          builder: (context, snapshot) {
            final text = snapshot.data?.text;
            return ListTile(
              title: Text(item.ayahKey),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (text != null)
                    Text(
                      text,
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'UthmanicHafs'),
                    ),
                  if (item.hasNote)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              isThreeLine: item.hasNote,
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'open') {
                    context.push('/surah/$surah?ayah=$ayah');
                  } else if (value == 'unbookmark') {
                    await ref
                        .read(userLibraryProvider.notifier)
                        .toggleBookmark(item.ayahKey);
                    if (!context.mounted) return;
                    showAppToast(context, 'Ayah bookmark removed');
                  } else if (value == 'note') {
                    final ayahModel = snapshot.data;
                    if (ayahModel == null) return;
                    await showAyahNoteEditor(
                      context: context,
                      ref: ref,
                      ayah: ayahModel,
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'open', child: Text('Open ayah')),
                  const PopupMenuItem(value: 'note', child: Text('Edit note')),
                  if (showBookmarkActions && item.bookmarked)
                    const PopupMenuItem(
                      value: 'unbookmark',
                      child: Text('Remove bookmark'),
                    ),
                ],
              ),
              onTap: () => context.push('/surah/$surah?ayah=$ayah'),
            );
          },
        );
      },
    );
  }
}
