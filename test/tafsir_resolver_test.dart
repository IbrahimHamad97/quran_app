import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exercises grouped-ayah resolution against the bundled tafsir DB when present.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('bundled tafsir.sqlite has six editions', () async {
    final dbPath = p.join(Directory.current.path, 'assets', 'db', 'tafsir.sqlite');
    if (!File(dbPath).existsSync()) {
      // Asset build still running / not yet committed in CI.
      return;
    }
    final db = await databaseFactory.openDatabase(dbPath, options: OpenDatabaseOptions(readOnly: true));
    final editions = await db.query('editions');
    expect(editions.length, 6);

    final ibn = editions.firstWhere((e) => e['slug'] == 'en-ibn-kathir');
    expect(ibn['language'], 'en');

    // Resolve a known ayah: prefer group text when present.
    final rows = await db.query(
      'tafsir',
      where: 'edition_id = ? AND ayah_key = ?',
      whereArgs: [ibn['id'], '1:1'],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    await db.close();
  });

  test('bundled quran.sqlite has 6236 ayahs', () async {
    final dbPath = p.join(Directory.current.path, 'assets', 'db', 'quran.sqlite');
    if (!File(dbPath).existsSync()) {
      return;
    }
    final db = await databaseFactory.openDatabase(dbPath, options: OpenDatabaseOptions(readOnly: true));
    final countRow = await db.rawQuery('SELECT COUNT(*) AS c FROM ayahs');
    expect(countRow.first['c'], 6236);
    final pagesRow =
        await db.rawQuery('SELECT COUNT(DISTINCT page) AS c FROM ayahs');
    expect(pagesRow.first['c'] as int, greaterThan(600));
    await db.close();
  });
}
