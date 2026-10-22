import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/preferences.dart';
import '../../data/models/models.dart';
import '../../data/repositories/tafsir_repository.dart';

Future<void> showTafsirSheet({
  required BuildContext context,
  required Ayah ayah,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return TafsirSheet(ayah: ayah, scrollController: controller);
      },
    ),
  );
}

class TafsirSheet extends ConsumerStatefulWidget {
  const TafsirSheet({
    super.key,
    required this.ayah,
    required this.scrollController,
  });

  final Ayah ayah;
  final ScrollController scrollController;

  @override
  ConsumerState<TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends ConsumerState<TafsirSheet> {
  late String _language;
  late String _editionSlug;
  TafsirPassage? _passage;
  List<TafsirEdition> _editions = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(appPreferencesProvider);
    _language = prefs.tafsirLanguage;
    _editionSlug = prefs.tafsirEditionSlug;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(tafsirRepositoryProvider);
      final editions = await repo.getEditions(language: _language);
      // Prefer matching language; if current slug wrong language, pick first.
      final hasCurrent = editions.any((e) => e.slug == _editionSlug);
      if (!hasCurrent && editions.isNotEmpty) {
        _editionSlug = editions.first.slug;
      }
      final passage = editions.isEmpty
          ? null
          : await repo.getPassage(
              editionSlug: _editionSlug,
              ayahKey: widget.ayah.key,
            );
      if (!mounted) return;
      setState(() {
        _editions = editions;
        _passage = passage;
        _loading = false;
      });
      await ref.read(appPreferencesProvider).setTafsirLanguage(_language);
      await ref
          .read(appPreferencesProvider)
          .setTafsirEditionSlug(_editionSlug);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(tafsirFontSizeProvider);
    final isRtl = _language == 'ar';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            'Tafsir · ${widget.ayah.key}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            widget.ayah.text,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'UthmanicHafs',
              fontSize: 22,
              height: 1.8,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('EN')),
                  ButtonSegment(value: 'ar', label: Text('AR')),
                ],
                selected: {_language},
                onSelectionChanged: (s) {
                  _language = s.first;
                  _load();
                },
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Zoom out',
                onPressed: () =>
                    ref.read(tafsirFontSizeProvider.notifier).bump(-1),
                icon: const Icon(Icons.text_decrease),
              ),
              IconButton(
                tooltip: 'Zoom in',
                onPressed: () =>
                    ref.read(tafsirFontSizeProvider.notifier).bump(1),
                icon: const Icon(Icons.text_increase),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_editions.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _editions.any((e) => e.slug == _editionSlug)
                  ? _editionSlug
                  : _editions.first.slug,
              decoration: const InputDecoration(
                labelText: 'Edition',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _editions
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.slug,
                      child: Text(e.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (slug) {
                if (slug == null) return;
                _editionSlug = slug;
                _load();
              },
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _passage == null || _passage!.isEmpty
                        ? const Center(
                            child: Text(
                              'No tafsir available for this ayah in the selected edition.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView(
                            controller: widget.scrollController,
                            children: [
                              if (_passage!.spansMultiple)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Covers ${_passage!.fromAyah} – ${_passage!.toAyah}',
                                    style:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                ),
                              Directionality(
                                textDirection: isRtl
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                child: Html(
                                  data: _wrapHtml(_passage!.text),
                                  style: {
                                    'body': Style(
                                      fontSize: FontSize(fontSize),
                                      lineHeight: LineHeight.number(1.6),
                                      margin: Margins.zero,
                                      padding: HtmlPaddings.zero,
                                    ),
                                  },
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  String _wrapHtml(String text) {
    final trimmed = text.trim();
    if (trimmed.contains('<') && trimmed.contains('>')) {
      return trimmed;
    }
    return '<p>${trimmed.replaceAll('\n\n', '</p><p>').replaceAll('\n', '<br/>')}</p>';
  }
}
