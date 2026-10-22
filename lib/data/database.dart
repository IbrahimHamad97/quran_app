import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabases {
  AppDatabases._();

  static Database? _quran;
  static Database? _tafsir;

  static Future<void> init() async {
    _quran = await _openAssetDb('quran.sqlite');
    _tafsir = await _openAssetDb('tafsir.sqlite');
  }

  static Database get quran {
    final db = _quran;
    if (db == null) {
      throw StateError('Quran database not initialized');
    }
    return db;
  }

  static Database get tafsir {
    final db = _tafsir;
    if (db == null) {
      throw StateError('Tafsir database not initialized');
    }
    return db;
  }

  static Future<Database> _openAssetDb(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, filename);
    final file = File(dbPath);

    // Copy from assets when missing or when asset is newer / larger rebuild.
    final assetData = await rootBundle.load('assets/db/$filename');
    final bytes = assetData.buffer.asUint8List();
    final needsCopy = !file.existsSync() || file.lengthSync() != bytes.length;
    if (needsCopy) {
      await file.writeAsBytes(bytes, flush: true);
    }

    return openDatabase(dbPath, readOnly: true, singleInstance: false);
  }

  static Future<void> close() async {
    await _quran?.close();
    await _tafsir?.close();
    _quran = null;
    _tafsir = null;
  }
}
