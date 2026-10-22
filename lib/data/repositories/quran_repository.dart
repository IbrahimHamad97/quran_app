import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database.dart';
import '../models/models.dart';

class QuranRepository {
  Future<List<Surah>> getSurahs() async {
    final rows = await AppDatabases.quran.query(
      'surahs',
      orderBy: 'number ASC',
    );
    return rows.map(Surah.fromMap).toList();
  }

  Future<Surah?> getSurah(int number) async {
    final rows = await AppDatabases.quran.query(
      'surahs',
      where: 'number = ?',
      whereArgs: [number],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Surah.fromMap(rows.first);
  }

  Future<List<Ayah>> getAyahsForSurah(int surah) async {
    final rows = await AppDatabases.quran.query(
      'ayahs',
      where: 'surah = ?',
      whereArgs: [surah],
      orderBy: 'ayah ASC',
    );
    return rows.map(Ayah.fromMap).toList();
  }

  /// Full mushaf order (1:1 → 114:6). Safe to cache — ~6k rows.
  Future<List<Ayah>> getAllAyahs() async {
    final rows = await AppDatabases.quran.query(
      'ayahs',
      orderBy: 'id ASC',
    );
    return rows.map(Ayah.fromMap).toList();
  }

  Future<Ayah?> getAyah(int surah, int ayah) async {
    final rows = await AppDatabases.quran.query(
      'ayahs',
      where: 'surah = ? AND ayah = ?',
      whereArgs: [surah, ayah],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Ayah.fromMap(rows.first);
  }

  Future<Ayah?> getFirstAyahOnPage(int page) async {
    final rows = await AppDatabases.quran.query(
      'ayahs',
      where: 'page = ?',
      whereArgs: [page],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Ayah.fromMap(rows.first);
  }

  Future<Ayah?> getFirstAyahInJuz(int juz) async {
    final rows = await AppDatabases.quran.query(
      'ayahs',
      where: 'juz = ?',
      whereArgs: [juz],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Ayah.fromMap(rows.first);
  }

  Future<List<Ayah>> searchArabic(String query, {int limit = 50}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final rows = await AppDatabases.quran.query(
      'ayahs',
      where: 'text LIKE ?',
      whereArgs: ['%$trimmed%'],
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(Ayah.fromMap).toList();
  }

  Future<List<Surah>> searchSurahs(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];
    final surahs = await getSurahs();
    return surahs.where((s) {
      return s.nameEn.toLowerCase().contains(trimmed) ||
          s.nameAr.contains(query.trim()) ||
          s.number.toString() == trimmed;
    }).toList();
  }
}

final quranRepositoryProvider = Provider<QuranRepository>((ref) {
  return QuranRepository();
});

final surahsProvider = FutureProvider<List<Surah>>((ref) {
  return ref.watch(quranRepositoryProvider).getSurahs();
});

final surahAyahsProvider =
    FutureProvider.family<List<Ayah>, int>((ref, surah) {
  return ref.watch(quranRepositoryProvider).getAyahsForSurah(surah);
});

final allAyahsProvider = FutureProvider<List<Ayah>>((ref) {
  return ref.watch(quranRepositoryProvider).getAllAyahs();
});
