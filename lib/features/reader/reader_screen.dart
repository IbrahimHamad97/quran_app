import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/preferences.dart';
import '../../data/models/models.dart';
import '../../data/repositories/quran_repository.dart';
import '../../data/user_library.dart';
import 'ayah_actions.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.surahNumber,
    this.initialAyah,
  });

  final int surahNumber;
  final int? initialAyah;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _scrollController = ScrollController();
  final _itemKeys = <int, GlobalKey>{};
  int? _stickyPage;
  int? _stickyJuz;
  int _visibleSurah = 1;
  bool _didJump = false;
  String? _lastSavedKey;
  DateTime _lastSaveAt = DateTime.fromMillisecondsSinceEpoch(0);
  Ayah? _selectedAyah;
  /// Progress only updates after scroll/select — not on accidental open.
  bool _userEngaged = false;

  @override
  void initState() {
    super.initState();
    _visibleSurah = widget.surahNumber;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int ayahId) =>
      _itemKeys.putIfAbsent(ayahId, GlobalKey.new);

  void _updateVisible(List<Ayah> ayahs) {
    if (!_scrollController.hasClients || ayahs.isEmpty) return;

    const estimated = 130.0;
    final approx = (_scrollController.offset / estimated)
        .floor()
        .clamp(0, ayahs.length - 1);
    final start = (approx - 12).clamp(0, ayahs.length - 1);
    final end = (approx + 12).clamp(0, ayahs.length - 1);

    Ayah? visible;
    final topBand = MediaQuery.sizeOf(context).height * 0.4;
    for (var i = start; i <= end; i++) {
      final ayah = ayahs[i];
      final ctx = _keyFor(ayah.id).currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final dy = box.localToGlobal(Offset.zero).dy;
      if (dy >= 0 && dy <= topBand) {
        visible = ayah;
        break;
      }
    }
    visible ??= ayahs[approx];

    final ayah = visible;
    final pageChanged = _stickyPage != ayah.page || _stickyJuz != ayah.juz;
    final surahChanged = _visibleSurah != ayah.surah;
    if (pageChanged || surahChanged) {
      setState(() {
        _stickyPage = ayah.page;
        _stickyJuz = ayah.juz;
        _visibleSurah = ayah.surah;
      });
    }

    if (_userEngaged) {
      _maybeSaveProgress(ayah);
    }
  }

  void _maybeSaveProgress(Ayah ayah) {
    final now = DateTime.now();
    if (ayah.key == _lastSavedKey) return;
    if (now.difference(_lastSaveAt) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastSaveAt = now;
    _lastSavedKey = ayah.key;
    ref.read(lastReadProvider.notifier).setPosition(ayah.surah, ayah.ayah);
  }

  void _selectAyah(Ayah ayah) {
    HapticFeedback.selectionClick();
    _userEngaged = true;
    setState(() {
      _selectedAyah = ayah;
      _visibleSurah = ayah.surah;
      _stickyPage = ayah.page;
      _stickyJuz = ayah.juz;
    });
    _maybeSaveProgress(ayah);
  }

  void _jumpTo(List<Ayah> ayahs, int surah, int ayahNumber) {
    final idx = ayahs.indexWhere(
      (a) => a.surah == surah && a.ayah == ayahNumber,
    );
    if (idx < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _keyFor(ayahs[idx].id).currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.15,
          duration: Duration.zero,
        );
      } else if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          (idx * 130.0).clamp(0, _scrollController.position.maxScrollExtent),
        );
      }
      setState(() {
        _selectedAyah = ayahs[idx];
        _stickyPage = ayahs[idx].page;
        _stickyJuz = ayahs[idx].juz;
        _visibleSurah = ayahs[idx].surah;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ayahsAsync = ref.watch(allAyahsProvider);
    final surahsAsync = ref.watch(surahsProvider);
    final fontSize = ref.watch(quranFontSizeProvider);
    final favorites = ref.watch(favoriteSurahsProvider);
    final library = ref.watch(userLibraryProvider);
    final isFavorite = favorites.contains(_visibleSurah);

    final surahName = surahsAsync.maybeWhen(
      data: (list) {
        final match = list.where((s) => s.number == _visibleSurah);
        return match.isEmpty ? 'Surah $_visibleSurah' : match.first.nameEn;
      },
      orElse: () => 'Surah $_visibleSurah',
    );
    final surahNameAr = surahsAsync.maybeWhen(
      data: (list) {
        final match = list.where((s) => s.number == _visibleSurah);
        return match.isEmpty ? null : match.first.nameAr;
      },
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(surahName, style: const TextStyle(fontSize: 16)),
            if (surahNameAr != null)
              Text(
                surahNameAr,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isFavorite ? 'Remove bookmark' : 'Bookmark surah',
            onPressed: () async {
              final name = surahName;
              final wasFavorite = isFavorite;
              final targetSurah = _visibleSurah;
              final messenger = ScaffoldMessenger.of(context);
              await ref
                  .read(favoriteSurahsProvider.notifier)
                  .toggle(targetSurah);
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    wasFavorite
                        ? '$name removed from bookmarks'
                        : '$name added to bookmarks',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: isFavorite ? Colors.amber.shade700 : null,
            ),
          ),
          IconButton(
            tooltip: 'Zoom out',
            onPressed: () =>
                ref.read(quranFontSizeProvider.notifier).bump(-2),
            icon: const Icon(Icons.text_decrease),
          ),
          IconButton(
            tooltip: 'Zoom in',
            onPressed: () =>
                ref.read(quranFontSizeProvider.notifier).bump(2),
            icon: const Icon(Icons.text_increase),
          ),
        ],
      ),
      body: ayahsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading ayahs\n$e')),
        data: (ayahs) {
          if (ayahs.isEmpty) {
            return const Center(child: Text('No ayahs found.'));
          }

          _stickyPage ??= ayahs.first.page;
          _stickyJuz ??= ayahs.first.juz;

          if (!_didJump) {
            _didJump = true;
            final startAyah = widget.initialAyah ?? 1;
            _jumpTo(ayahs, widget.surahNumber, startAyah);
          }

          return Column(
            children: [
              Material(
                elevation: 1,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        'Page ${_stickyPage ?? ayahs.first.page}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Juz ${_stickyJuz ?? ayahs.first.juz}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      Text(
                        'Continuous',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollUpdateNotification) {
                      if ((n.scrollDelta?.abs() ?? 0) > 1.5) {
                        _userEngaged = true;
                      }
                      _updateVisible(ayahs);
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    cacheExtent: 1200,
                    addAutomaticKeepAlives: false,
                    itemCount: ayahs.length,
                    itemBuilder: (context, index) {
                      final ayah = ayahs[index];
                      final prev = index > 0 ? ayahs[index - 1] : null;
                      final showSurahHeader =
                          prev == null || prev.surah != ayah.surah;
                      final showPageBreak =
                          prev != null && prev.page != ayah.page;
                      final selected = _selectedAyah?.key == ayah.key;
                      final annotation = library[ayah.key];
                      final headerSurah = surahsAsync.maybeWhen(
                        data: (list) {
                          final m = list.where((s) => s.number == ayah.surah);
                          return m.isEmpty ? null : m.first;
                        },
                        orElse: () => null,
                      );

                      return RepaintBoundary(
                        key: _keyFor(ayah.id),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showSurahHeader)
                              _SurahHeader(
                                surahNumber: ayah.surah,
                                nameAr: headerSurah?.nameAr,
                                nameEn: headerSurah?.nameEn,
                              ),
                            if (showPageBreak && !showSurahHeader)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    const Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Chip(
                                        label: Text('Page ${ayah.page}'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    const Expanded(child: Divider()),
                                  ],
                                ),
                              ),
                            _AyahTile(
                              ayah: ayah,
                              fontSize: fontSize,
                              selected: selected,
                              bookmarked: annotation?.bookmarked ?? false,
                              hasNote: annotation?.hasNote ?? false,
                              onTap: () => _selectAyah(ayah),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: _selectedAyah == null
                    ? const SizedBox.shrink(key: ValueKey('no-bar'))
                    : AyahActionBar(
                        key: ValueKey(_selectedAyah!.key),
                        ayah: _selectedAyah!,
                        onClose: () => setState(() => _selectedAyah = null),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({
    required this.surahNumber,
    required this.nameAr,
    required this.nameEn,
  });

  final int surahNumber;
  final String? nameAr;
  final String? nameEn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              'Surah $surahNumber',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
            ),
            if (nameAr != null) ...[
              const SizedBox(height: 4),
              Text(
                nameAr!,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 26,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ],
            if (nameEn != null)
              Text(
                nameEn!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AyahTile extends StatelessWidget {
  const _AyahTile({
    required this.ayah,
    required this.fontSize,
    required this.selected,
    required this.bookmarked,
    required this.hasNote,
    required this.onTap,
  });

  final Ayah ayah;
  final double fontSize;
  final bool selected;
  final bool bookmarked;
  final bool hasNote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: selected
            ? Border.all(color: scheme.primary, width: 1.5)
            : Border.all(color: Colors.transparent),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ayah.text,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: fontSize,
                  height: 1.9,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${ayah.surah}:${ayah.ayah} · p.${ayah.page}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const Spacer(),
                  if (bookmarked)
                    Icon(Icons.bookmark, size: 16, color: scheme.primary),
                  if (hasNote) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.sticky_note_2,
                      size: 16,
                      color: scheme.tertiary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
