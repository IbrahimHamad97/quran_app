import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/data/models/models.dart';

void main() {
  test('Ayah key formatting', () {
    const ayah = Ayah(
      id: 1,
      surah: 2,
      ayah: 255,
      text: 'test',
      page: 42,
      juz: 3,
    );
    expect(ayah.key, '2:255');
  });

  test('TafsirPassage empty detection', () {
    const empty = TafsirPassage(
      ayahKey: '1:1',
      groupAyahKey: '1:1',
      fromAyah: '1:1',
      toAyah: '1:1',
      text: '   ',
    );
    const filled = TafsirPassage(
      ayahKey: '1:1',
      groupAyahKey: '1:1',
      fromAyah: '1:1',
      toAyah: '1:2',
      text: 'Commentary',
    );
    expect(empty.isEmpty, isTrue);
    expect(filled.isEmpty, isFalse);
    expect(filled.spansMultiple, isTrue);
  });

  test('Surah.fromMap', () {
    final surah = Surah.fromMap({
      'number': 1,
      'name_ar': 'الفاتحة',
      'name_en': 'Al-Fatihah',
      'ayah_count': 7,
    });
    expect(surah.number, 1);
    expect(surah.ayahCount, 7);
  });
}
