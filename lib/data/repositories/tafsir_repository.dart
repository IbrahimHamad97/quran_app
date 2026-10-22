import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database.dart';
import '../models/models.dart';

class TafsirRepository {
  Future<List<TafsirEdition>> getEditions({String? language}) async {
    final rows = language == null
        ? await AppDatabases.tafsir.query('editions', orderBy: 'id ASC')
        : await AppDatabases.tafsir.query(
            'editions',
            where: 'language = ?',
            whereArgs: [language],
            orderBy: 'id ASC',
          );
    return rows.map(TafsirEdition.fromMap).toList();
  }

  Future<TafsirEdition?> getEditionBySlug(String slug) async {
    final rows = await AppDatabases.tafsir.query(
      'editions',
      where: 'slug = ?',
      whereArgs: [slug],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TafsirEdition.fromMap(rows.first);
  }

  /// Resolves grouped tafsir: if the row text is empty, follow group_ayah_key.
  Future<TafsirPassage?> getPassage({
    required String editionSlug,
    required String ayahKey,
  }) async {
    final edition = await getEditionBySlug(editionSlug);
    if (edition == null) return null;

    final rows = await AppDatabases.tafsir.query(
      'tafsir',
      where: 'edition_id = ? AND ayah_key = ?',
      whereArgs: [edition.id, ayahKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      // Some dumps only store group rows; try matching group key.
      final groupRows = await AppDatabases.tafsir.query(
        'tafsir',
        where: 'edition_id = ? AND group_ayah_key = ? AND text != ?',
        whereArgs: [edition.id, ayahKey, ''],
        limit: 1,
      );
      if (groupRows.isEmpty) return null;
      return _fromRow(groupRows.first, ayahKey);
    }

    final row = rows.first;
    var text = (row['text'] as String?) ?? '';
    final groupKey = (row['group_ayah_key'] as String?) ?? ayahKey;

    if (text.trim().isEmpty && groupKey != ayahKey) {
      final groupRows = await AppDatabases.tafsir.query(
        'tafsir',
        where: 'edition_id = ? AND ayah_key = ?',
        whereArgs: [edition.id, groupKey],
        limit: 1,
      );
      if (groupRows.isNotEmpty) {
        text = (groupRows.first['text'] as String?) ?? '';
      }
    }

    if (text.trim().isEmpty) {
      final groupRows = await AppDatabases.tafsir.query(
        'tafsir',
        where: 'edition_id = ? AND group_ayah_key = ? AND length(text) > 0',
        whereArgs: [edition.id, groupKey],
        limit: 1,
      );
      if (groupRows.isNotEmpty) {
        text = (groupRows.first['text'] as String?) ?? '';
      }
    }

    return TafsirPassage(
      ayahKey: ayahKey,
      groupAyahKey: groupKey,
      fromAyah: (row['from_ayah'] as String?) ?? ayahKey,
      toAyah: (row['to_ayah'] as String?) ?? ayahKey,
      text: text,
    );
  }

  TafsirPassage _fromRow(Map<String, Object?> row, String ayahKey) {
    return TafsirPassage(
      ayahKey: ayahKey,
      groupAyahKey: (row['group_ayah_key'] as String?) ?? ayahKey,
      fromAyah: (row['from_ayah'] as String?) ?? ayahKey,
      toAyah: (row['to_ayah'] as String?) ?? ayahKey,
      text: (row['text'] as String?) ?? '',
    );
  }
}

final tafsirRepositoryProvider = Provider<TafsirRepository>((ref) {
  return TafsirRepository();
});

final tafsirEditionsProvider =
    FutureProvider.family<List<TafsirEdition>, String?>((ref, language) {
  return ref.watch(tafsirRepositoryProvider).getEditions(language: language);
});
