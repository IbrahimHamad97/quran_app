import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback.dart';
import '../../core/preferences.dart';
import '../../data/models/models.dart';
import '../../data/repositories/quran_repository.dart';

class SurahListScreen extends ConsumerWidget {
  const SurahListScreen({super.key});

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    Surah surah,
  ) async {
    final wasFavorite =
        ref.read(favoriteSurahsProvider).contains(surah.number);
    await ref.read(favoriteSurahsProvider.notifier).toggle(surah.number);
    if (!context.mounted) return;
    showAppToast(
      context,
      wasFavorite
          ? '${surah.nameEn} removed from bookmarks'
          : '${surah.nameEn} added to bookmarks',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahsAsync = ref.watch(surahsProvider);
    final lastRead = ref.watch(lastReadProvider);
    final favorites = ref.watch(favoriteSurahsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran & Tafsir'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            tooltip: 'Browse juz / pages',
            icon: const Icon(Icons.grid_view_outlined),
            onPressed: () => context.push('/browse'),
          ),
          IconButton(
            tooltip: 'Bookmarks & notes',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => context.push('/library'),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: surahsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load surahs.\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (surahs) {
          final byNumber = {for (final s in surahs) s.number: s};

          return CustomScrollView(
            slivers: [
              if (lastRead != null)
                SliverToBoxAdapter(
                  child: _ResumeCard(
                    surah: byNumber[lastRead.surah],
                    lastRead: lastRead,
                    onTap: () => context.push(
                      '/surah/${lastRead.surah}?ayah=${lastRead.ayah}',
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    lastRead == null ? 16 : 12,
                    16,
                    8,
                  ),
                  child: Text(
                    'Surahs',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              SliverList.separated(
                itemCount: surahs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final surah = surahs[index];
                  final isFavorite = favorites.contains(surah.number);
                  return _SurahTile(
                    surah: surah,
                    isFavorite: isFavorite,
                    onToggleFavorite: () =>
                        _toggleFavorite(context, ref, surah),
                    onTap: () => context.push('/surah/${surah.number}'),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.surah,
    required this.lastRead,
    required this.onTap,
  });

  final Surah? surah;
  final LastRead lastRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nameEn = surah?.nameEn ?? 'Surah ${lastRead.surah}';
    final nameAr = surah?.nameAr;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resume reading',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.onPrimaryContainer
                                  .withValues(alpha: 0.8),
                            ),
                      ),
                      const SizedBox(height: 4),
                      if (nameAr != null)
                        Text(
                          nameAr,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: 'UthmanicHafs',
                            fontSize: 22,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      Text(
                        '$nameEn · Ayah ${lastRead.ayah}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        'Surah ${lastRead.surah} · ${lastRead.surah}:${lastRead.ayah}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onPrimaryContainer
                                  .withValues(alpha: 0.75),
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({
    required this.surah,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final Surah surah;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text('${surah.number}')),
      title: Text(
        surah.nameAr,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          fontFamily: 'UthmanicHafs',
          fontSize: 22,
        ),
      ),
      subtitle: Text('${surah.nameEn} · ${surah.ayahCount} ayahs'),
      trailing: IconButton(
        tooltip: isFavorite ? 'Remove bookmark' : 'Bookmark surah',
        onPressed: onToggleFavorite,
        icon: Icon(
          isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
          color: isFavorite ? Colors.amber.shade700 : null,
        ),
      ),
      onTap: onTap,
    );
  }
}
