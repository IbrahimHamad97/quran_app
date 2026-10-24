import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/preferences.dart';
import '../../data/models/models.dart';
import '../../data/repositories/quran_repository.dart';
import '../../data/user_library.dart';
import 'ayah_actions.dart';

const _ayahGold = Color(0xFFC9A227);

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
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();

  int? _stickyPage;
  int? _stickyJuz;
  int _visibleSurah = 1;
  String? _lastSavedKey;
  DateTime _lastSaveAt = DateTime.fromMillisecondsSinceEpoch(0);
  Ayah? _selectedAyah;
  Ayah? _trackedAyah;
  bool _userEngaged = false;
  bool _trackScheduled = false;
  bool _didInitialTrack = false;
  bool _didResumeScroll = false;
  int _resumeScrollTries = 0;
  int _landingPageIndex = 0;
  List<List<Ayah>> _pages = const [];
  Ayah? _resumeTarget;

  /// Ayah end-markers for the reading-line hit test (visible pages only).
  final _markers = <String, ({GlobalKey key, Ayah ayah})>{};

  /// Surah banner keys — used to land on a surah start mid-page.
  final _surahHeaderKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _visibleSurah = widget.surahNumber;
    _itemPositionsListener.itemPositions.addListener(_scheduleTrackSync);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_scheduleTrackSync);
    super.dispose();
  }

  GlobalKey _markerKeyFor(Ayah ayah) {
    final existing = _markers[ayah.key];
    if (existing != null) return existing.key;
    final key = GlobalKey(debugLabel: 'ayah-${ayah.key}');
    _markers[ayah.key] = (key: key, ayah: ayah);
    return key;
  }

  GlobalKey _surahHeaderKeyFor(int surahNumber) {
    return _surahHeaderKeys.putIfAbsent(
      surahNumber,
      () => GlobalKey(debugLabel: 'surah-header-$surahNumber'),
    );
  }

  List<List<Ayah>> _buildPages(List<Ayah> ayahs) {
    if (ayahs.isEmpty) return const [];
    final byPage = <int, List<Ayah>>{};
    for (final a in ayahs) {
      byPage.putIfAbsent(a.page, () => []).add(a);
    }
    final maxPage = byPage.keys.reduce((a, b) => a > b ? a : b);
    return [
      for (var p = 1; p <= maxPage; p++) byPage[p] ?? const <Ayah>[],
    ];
  }

  int _pageIndexFor(List<Ayah> ayahs, int surah, int ayahNumber) {
    for (final a in ayahs) {
      if (a.surah == surah && a.ayah == ayahNumber) {
        return (a.page - 1).clamp(0, 603);
      }
    }
    return 0;
  }

  Ayah? _findAyah(List<Ayah> ayahs, int surah, int ayahNumber) {
    for (final a in ayahs) {
      if (a.surah == surah && a.ayah == ayahNumber) return a;
    }
    return null;
  }

  void _scheduleTrackSync() {
    if (_trackScheduled) return;
    _trackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackScheduled = false;
      if (mounted) _syncTrackedAyah();
    });
  }

  /// Pages currently intersecting the viewport (sorted top → bottom).
  List<ItemPosition> _visiblePagePositions() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return const [];
    final visible = positions
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
        .toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    return visible;
  }

  /// Page whose body covers the reading line (near the top of the list viewport).
  ItemPosition? _pageAtReadingEdge(List<ItemPosition> visible) {
    if (visible.isEmpty) return null;
    // List viewport is below the app bar; reading line ≈ top of that viewport.
    const readingEdge = 0.02;
    for (final p in visible) {
      if (p.itemLeadingEdge <= readingEdge && p.itemTrailingEdge > readingEdge) {
        return p;
      }
    }
    return visible.first;
  }

  /// Rough ayah on a page from how far that list item has scrolled.
  Ayah? _ayahFromPageScroll(ItemPosition pos) {
    if (pos.index < 0 || pos.index >= _pages.length) return null;
    final pageAyahs = _pages[pos.index];
    if (pageAyahs.isEmpty) return null;

    final extent = pos.itemTrailingEdge - pos.itemLeadingEdge;
    if (extent <= 0) return pageAyahs.first;

    // How much of this page has moved above the viewport top.
    final scrolledPast = (-pos.itemLeadingEdge / extent).clamp(0.0, 1.0);
    // Small bias: ayah whose text is at the top of the viewport.
    final t = (scrolledPast + 0.04).clamp(0.0, 1.0);
    final idx =
        (t * (pageAyahs.length - 1)).round().clamp(0, pageAyahs.length - 1);
    return pageAyahs[idx];
  }

  /// Ayah currently being read: the one whose end-marker is still ahead of
  /// (below) the reading line. Preferring "ahead" over "past" means the header
  /// updates as soon as that ayah's text reaches the line — not two lines later.
  Ayah? _ayahFromVisibleMarkers(Set<String> allowedKeys, double readingLine) {
    if (allowedKeys.isEmpty || _markers.isEmpty) return null;

    final media = MediaQuery.of(context);
    final maxY = media.size.height + 40;

    Ayah? bestPast;
    var bestPastY = -double.infinity;
    Ayah? bestAhead;
    var bestAheadY = double.infinity;

    for (final key in allowedKeys) {
      final entry = _markers[key];
      if (entry == null) continue;
      final ctx = entry.key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y < -40 || y > maxY) continue;

      if (y <= readingLine) {
        if (y > bestPastY) {
          bestPastY = y;
          bestPast = entry.ayah;
        }
      } else if (y < bestAheadY) {
        bestAheadY = y;
        bestAhead = entry.ayah;
      }
    }

    return bestAhead ?? bestPast;
  }

  /// Keep app-bar surah / page / ayah in sync with scroll.
  void _syncTrackedAyah() {
    if (!mounted || _pages.isEmpty) return;

    final visible = _visiblePagePositions();
    if (visible.isEmpty) return;

    final pageAtLine = _pageAtReadingEdge(visible);
    if (pageAtLine == null) return;

    // Only markers on the page under the reading line — otherwise a previous
    // page still in the cache can keep the app bar stuck on the old surah.
    final allowedKeys = <String>{};
    if (pageAtLine.index >= 0 && pageAtLine.index < _pages.length) {
      for (final a in _pages[pageAtLine.index]) {
        allowedKeys.add(a.key);
      }
    }

    final media = MediaQuery.of(context);
    final toolbarH = _stickyPage != null ? 72.0 : 56.0;
    // Focus line ~1 content line under the app bar (not the absolute top).
    final readingLine = media.padding.top + toolbarH + 28.0;

    // Prefer real marker geometry; fall back to list-item scroll fraction so
    // we never keep a stale surah/page while markers are unmounted mid-scroll.
    final ayah = _ayahFromVisibleMarkers(allowedKeys, readingLine) ??
        _ayahFromPageScroll(pageAtLine);
    if (ayah == null) return;

    final changed = _trackedAyah?.key != ayah.key ||
        _stickyPage != ayah.page ||
        _stickyJuz != ayah.juz ||
        _visibleSurah != ayah.surah;
    if (changed) {
      setState(() {
        _trackedAyah = ayah;
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
      _trackedAyah = ayah;
      _visibleSurah = ayah.surah;
      _stickyPage = ayah.page;
      _stickyJuz = ayah.juz;
    });
    _maybeSaveProgress(ayah);
  }

  void _markEngagedFromScroll() {
    if (!_userEngaged) _userEngaged = true;
  }

  /// Widget to pin at the top: surah banner for ayah 1, else previous end-mark
  /// so this ayah's text begins at the top (without overshooting past it).
  BuildContext? _resumeAnchorContext(Ayah target) {
    if (target.ayah == 1) {
      return _surahHeaderKeys[target.surah]?.currentContext;
    }
    final pageIndex = (target.page - 1).clamp(0, _pages.length - 1);
    final pageAyahs = _pages[pageIndex];
    final i = pageAyahs.indexWhere((a) => a.key == target.key);
    if (i <= 0) return null;
    return _markers[pageAyahs[i - 1].key]?.key.currentContext;
  }

  /// After landing on the page top, nudge so the target surah/ayah start is visible.
  void _scrollResumeAyahToTop() {
    if (_didResumeScroll || !mounted) return;
    final target = _resumeTarget;
    if (target == null) {
      _didResumeScroll = true;
      return;
    }

    final pageIndex = (target.page - 1).clamp(0, _pages.length - 1);
    final pageAyahs = _pages[pageIndex];
    final i = pageAyahs.indexWhere((a) => a.key == target.key);

    // Target is already the first content on this page — page top is enough.
    if (i <= 0) {
      _didResumeScroll = true;
      return;
    }

    final ctx = _resumeAnchorContext(target);
    if (ctx == null) {
      _resumeScrollTries++;
      if (_resumeScrollTries < 12) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollResumeAyahToTop();
        });
      } else {
        _didResumeScroll = true;
      }
      return;
    }

    _didResumeScroll = true;
    // Single ensureVisible from page-top — no pre-offset (that was overshooting).
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: Duration.zero,
      curve: Curves.linear,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleTrackSync();
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
    final scheme = Theme.of(context).colorScheme;

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
        toolbarHeight: _stickyPage != null ? 72 : 56,
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
            if (_stickyPage != null)
              Text(
                _trackedAyah != null
                    ? 'Page $_stickyPage · Juz ${_stickyJuz ?? '—'} · ${_trackedAyah!.key}'
                    : 'Page $_stickyPage · Juz ${_stickyJuz ?? '—'}',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
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

          _pages = _buildPages(ayahs);
          final startAyah = widget.initialAyah ?? 1;
          _landingPageIndex =
              _pageIndexFor(ayahs, widget.surahNumber, startAyah);
          final landingPage = _pages[_landingPageIndex];
          final landing =
              landingPage.isNotEmpty ? landingPage.first : ayahs.first;
          _stickyPage ??= landing.page;
          _stickyJuz ??= landing.juz;

          final target =
              _findAyah(ayahs, widget.surahNumber, startAyah);
          _resumeTarget ??= target;
          _trackedAyah ??= target ?? landing;
          if (!_didInitialTrack) {
            _didInitialTrack = true;
            // Land on page top first, then pin surah/ayah start (avoids overshoot).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollResumeAyahToTop();
              _scheduleTrackSync();
            });
          }

          return Column(
            children: [
              Expanded(
                  child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollUpdateNotification &&
                        (n.scrollDelta?.abs() ?? 0) > 0.5) {
                      _markEngagedFromScroll();
                      _scheduleTrackSync();
                    } else if (n is ScrollEndNotification) {
                      _scheduleTrackSync();
                    }
                    return false;
                  },
                  child: ScrollablePositionedList.builder(
                    itemScrollController: _itemScrollController,
                    itemPositionsListener: _itemPositionsListener,
                    initialScrollIndex: _landingPageIndex,
                    initialAlignment: 0.0,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final pageAyahs = _pages[index];
                      if (pageAyahs.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final pageNumber = pageAyahs.first.page;
                      final showTopDivider = index > 0;

                      // A Madani page can end one surah and start the next.
                      // Render previous-surah ayahs first, then the new header.
                      final pageChildren = <Widget>[
                        if (showTopDivider) _PageBreak(page: pageNumber),
                      ];
                      var cursor = 0;
                      while (cursor < pageAyahs.length) {
                        final current = pageAyahs[cursor];
                        if (current.ayah == 1) {
                          final headerSurah = surahsAsync.maybeWhen(
                            data: (list) {
                              final m =
                                  list.where((s) => s.number == current.surah);
                              return m.isEmpty ? null : m.first;
                            },
                            orElse: () => null,
                          );
                          pageChildren.add(
                            _SurahHeader(
                              key: _surahHeaderKeyFor(current.surah),
                              surahNumber: current.surah,
                              nameAr: headerSurah?.nameAr,
                              nameEn: headerSurah?.nameEn,
                            ),
                          );
                        }
                        final chunk = <Ayah>[];
                        final surahNo = current.surah;
                        while (cursor < pageAyahs.length &&
                            pageAyahs[cursor].surah == surahNo) {
                          chunk.add(pageAyahs[cursor]);
                          cursor++;
                        }
                        pageChildren.add(
                          _MushafPage(
                            key: ValueKey(
                              'mushaf-${chunk.first.key}-${chunk.last.key}',
                            ),
                            ayahs: chunk,
                            fontSize: fontSize,
                            selectedKey: _selectedAyah?.key,
                            library: library,
                            onSelect: _selectAyah,
                            preferSelectKey: index == _landingPageIndex
                                ? target?.key
                                : null,
                            markerKeyFor: _markerKeyFor,
                          ),
                        );
                      }

                      return Column(
                        key: ValueKey('page-$pageNumber'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: pageChildren,
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

class _PageBreak extends StatelessWidget {
  const _PageBreak({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(child: Divider(color: muted.withValues(alpha: 0.35))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '$page',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: muted,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(child: Divider(color: muted.withValues(alpha: 0.35))),
        ],
      ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({
    super.key,
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
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
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

class _MushafPage extends StatefulWidget {
  const _MushafPage({
    super.key,
    required this.ayahs,
    required this.fontSize,
    required this.selectedKey,
    required this.library,
    required this.onSelect,
    required this.markerKeyFor,
    this.preferSelectKey,
  });

  final List<Ayah> ayahs;
  final double fontSize;
  final String? selectedKey;
  final Map<String, AyahAnnotation> library;
  final ValueChanged<Ayah> onSelect;
  final GlobalKey Function(Ayah ayah) markerKeyFor;
  final String? preferSelectKey;

  @override
  State<_MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<_MushafPage>
    with SingleTickerProviderStateMixin {
  final _recognizers = <TapGestureRecognizer>[];
  late final AnimationController _highlightAnim;
  late final Animation<double> _highlightT;
  String? _animatedKey;

  @override
  void initState() {
    super.initState();
    _highlightAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _highlightT = CurvedAnimation(
      parent: _highlightAnim,
      curve: Curves.easeOutCubic,
    );
    _animatedKey = widget.selectedKey ?? widget.preferSelectKey;
    if (_animatedKey != null) {
      _highlightAnim.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _MushafPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ayahs != widget.ayahs) {
      _clearRecognizers();
    }
    final nextKey = widget.selectedKey ?? widget.preferSelectKey;
    if (nextKey != _animatedKey) {
      _animatedKey = nextKey;
      if (nextKey != null) {
        _highlightAnim.forward(from: 0);
      } else {
        _highlightAnim.reverse();
      }
    }
  }

  @override
  void dispose() {
    _clearRecognizers();
    _highlightAnim.dispose();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _recognizerFor(Ayah ayah) {
    final r = TapGestureRecognizer()..onTap = () => widget.onSelect(ayah);
    _recognizers.add(r);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onSurface;

    return AnimatedBuilder(
      animation: _highlightT,
      builder: (context, _) {
        final spans = <InlineSpan>[];
        for (final ayah in widget.ayahs) {
          final selected = widget.selectedKey == ayah.key ||
              (widget.selectedKey == null &&
                  widget.preferSelectKey == ayah.key);
          final annotation = widget.library[ayah.key];
          final marked = (annotation?.bookmarked ?? false) ||
              (annotation?.hasNote ?? false);

          // Soft gold wash (not the green block from other apps), fades in.
          final highlight = selected
              ? Color.lerp(
                  Colors.transparent,
                  const Color(0x55D4AF37),
                  _highlightT.value,
                )
              : null;

          spans.add(
            TextSpan(
              text: ayah.text,
              style: TextStyle(
                fontFamily: 'UthmanicHafs',
                fontSize: widget.fontSize,
                height: 2.05,
                color: ink,
                backgroundColor: highlight,
              ),
              recognizer: _recognizerFor(ayah),
            ),
          );
          final digits = '${ayah.ayah}'.length;
          final markerSize = widget.fontSize *
              (digits >= 3 ? 1.35 : digits == 2 ? 1.1 : 0.95);
          final markerFont = widget.fontSize *
              (digits >= 3 ? 0.30 : digits == 2 ? 0.34 : 0.38);

          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                key: widget.markerKeyFor(ayah),
                onTap: () => widget.onSelect(ayah),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: markerSize,
                    height: markerSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? scheme.primary : _ayahGold,
                        width: selected ? 1.6 : 1.2,
                      ),
                      color: marked
                          ? _ayahGold.withValues(alpha: 0.18)
                          : (selected
                              ? scheme.primary.withValues(alpha: 0.12)
                              : Colors.transparent),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          '${ayah.ayah}',
                          style: TextStyle(
                            fontSize: markerFont,
                            fontWeight: FontWeight.w600,
                            color: selected ? scheme.primary : _ayahGold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          spans.add(const TextSpan(text: ' '));
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 14),
          child: Text.rich(
            TextSpan(children: spans),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
          ),
        );
      },
    );
  }
}
