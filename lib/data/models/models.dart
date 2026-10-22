class Surah {
  const Surah({
    required this.number,
    required this.nameAr,
    required this.nameEn,
    required this.ayahCount,
  });

  final int number;
  final String nameAr;
  final String nameEn;
  final int ayahCount;

  factory Surah.fromMap(Map<String, Object?> map) {
    return Surah(
      number: map['number'] as int,
      nameAr: map['name_ar'] as String,
      nameEn: map['name_en'] as String,
      ayahCount: map['ayah_count'] as int,
    );
  }
}

class Ayah {
  const Ayah({
    required this.id,
    required this.surah,
    required this.ayah,
    required this.text,
    required this.page,
    required this.juz,
  });

  final int id;
  final int surah;
  final int ayah;
  final String text;
  final int page;
  final int juz;

  String get key => '$surah:$ayah';

  factory Ayah.fromMap(Map<String, Object?> map) {
    return Ayah(
      id: map['id'] as int,
      surah: map['surah'] as int,
      ayah: map['ayah'] as int,
      text: map['text'] as String,
      page: map['page'] as int,
      juz: map['juz'] as int,
    );
  }
}

class TafsirEdition {
  const TafsirEdition({
    required this.id,
    required this.slug,
    required this.name,
    required this.language,
  });

  final int id;
  final String slug;
  final String name;
  final String language;

  factory TafsirEdition.fromMap(Map<String, Object?> map) {
    return TafsirEdition(
      id: map['id'] as int,
      slug: map['slug'] as String,
      name: map['name'] as String,
      language: map['language'] as String,
    );
  }
}

class TafsirPassage {
  const TafsirPassage({
    required this.ayahKey,
    required this.groupAyahKey,
    required this.fromAyah,
    required this.toAyah,
    required this.text,
  });

  final String ayahKey;
  final String groupAyahKey;
  final String fromAyah;
  final String toAyah;
  final String text;

  bool get isEmpty => text.trim().isEmpty;

  bool get spansMultiple => fromAyah != toAyah;
}
