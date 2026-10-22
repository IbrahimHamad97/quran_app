import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../data/repositories/quran_repository.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  List<Surah> _surahHits = const [];
  List<Ayah> _ayahHits = const [];
  bool _searching = false;
  String? _hint;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) {
      setState(() {
        _surahHits = const [];
        _ayahHits = const [];
        _hint = null;
      });
      return;
    }

    setState(() => _searching = true);
    final repo = ref.read(quranRepositoryProvider);

    // Direct jump: 2:255 or 2 255
    final keyMatch =
        RegExp(r'^(\d{1,3})\s*[:\s]\s*(\d{1,3})$').firstMatch(query);
    if (keyMatch != null) {
      final surah = int.parse(keyMatch.group(1)!);
      final ayah = int.parse(keyMatch.group(2)!);
      final hit = await repo.getAyah(surah, ayah);
      setState(() {
        _searching = false;
        _surahHits = const [];
        _ayahHits = hit == null ? const [] : [hit];
        _hint = hit == null ? 'No ayah found for $surah:$ayah' : null;
      });
      return;
    }

    // Page jump: p12 / page 12
    final pageMatch =
        RegExp(r'^(?:p|page)\s*(\d{1,3})$', caseSensitive: false)
            .firstMatch(query);
    if (pageMatch != null) {
      final page = int.parse(pageMatch.group(1)!);
      final hit = await repo.getFirstAyahOnPage(page);
      setState(() {
        _searching = false;
        _surahHits = const [];
        _ayahHits = hit == null ? const [] : [hit];
        _hint = hit == null ? 'No ayah found on page $page' : 'Page $page';
      });
      return;
    }

    // Juz jump: j5 / juz 5
    final juzMatch =
        RegExp(r'^(?:j|juz)\s*(\d{1,2})$', caseSensitive: false)
            .firstMatch(query);
    if (juzMatch != null) {
      final juz = int.parse(juzMatch.group(1)!);
      final hit = await repo.getFirstAyahInJuz(juz);
      setState(() {
        _searching = false;
        _surahHits = const [];
        _ayahHits = hit == null ? const [] : [hit];
        _hint = hit == null ? 'No ayah found in juz $juz' : 'Juz $juz';
      });
      return;
    }

    final surahs = await repo.searchSurahs(query);
    final ayahs = await repo.searchArabic(query);
    setState(() {
      _searching = false;
      _surahHits = surahs;
      _ayahHits = ayahs;
      _hint = (surahs.isEmpty && ayahs.isEmpty) ? 'No results' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Surah name, 2:255, page 12, juz 5, Arabic…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _runSearch('');
                          setState(() {});
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                setState(() {});
                _runSearch(v);
              },
              onSubmitted: _runSearch,
            ),
          ),
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          if (_hint != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_hint!),
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                if (_surahHits.isNotEmpty) ...[
                  const ListTile(title: Text('Surahs')),
                  ..._surahHits.map(
                    (s) => ListTile(
                      leading: CircleAvatar(child: Text('${s.number}')),
                      title: Text(
                        s.nameAr,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontFamily: 'UthmanicHafs'),
                      ),
                      subtitle: Text(s.nameEn),
                      onTap: () => context.push('/surah/${s.number}'),
                    ),
                  ),
                ],
                if (_ayahHits.isNotEmpty) ...[
                  const ListTile(title: Text('Ayahs')),
                  ..._ayahHits.map(
                    (a) => ListTile(
                      title: Text(
                        a.text,
                        textDirection: TextDirection.rtl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'UthmanicHafs'),
                      ),
                      subtitle: Text(
                        '${a.key} · page ${a.page} · juz ${a.juz}',
                      ),
                      onTap: () =>
                          context.push('/surah/${a.surah}?ayah=${a.ayah}'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
