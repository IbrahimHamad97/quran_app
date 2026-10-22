import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/preferences.dart';

class AyahAnnotation {
  const AyahAnnotation({
    required this.ayahKey,
    required this.bookmarked,
    this.note = '',
    this.updatedAt,
  });

  final String ayahKey;
  final bool bookmarked;
  final String note;
  final DateTime? updatedAt;

  bool get hasNote => note.trim().isNotEmpty;

  AyahAnnotation copyWith({
    bool? bookmarked,
    String? note,
    DateTime? updatedAt,
  }) {
    return AyahAnnotation(
      ayahKey: ayahKey,
      bookmarked: bookmarked ?? this.bookmarked,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'ayahKey': ayahKey,
        'bookmarked': bookmarked,
        'note': note,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory AyahAnnotation.fromJson(Map<String, dynamic> json) {
    return AyahAnnotation(
      ayahKey: json['ayahKey'] as String,
      bookmarked: json['bookmarked'] as bool? ?? false,
      note: json['note'] as String? ?? '',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

class UserLibrary {
  UserLibrary(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'ayah_annotations_v1';

  Map<String, AyahAnnotation> loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(
        key,
        AyahAnnotation.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  Future<void> saveAll(Map<String, AyahAnnotation> data) async {
    final encoded = jsonEncode(
      data.map((key, value) => MapEntry(key, value.toJson())),
    );
    await _prefs.setString(_key, encoded);
  }
}

class UserLibraryNotifier extends StateNotifier<Map<String, AyahAnnotation>> {
  UserLibraryNotifier(this._library) : super(_library.loadAll());

  final UserLibrary _library;

  AyahAnnotation? of(String ayahKey) => state[ayahKey];

  bool isBookmarked(String ayahKey) => state[ayahKey]?.bookmarked ?? false;

  String noteFor(String ayahKey) => state[ayahKey]?.note ?? '';

  Future<void> toggleBookmark(String ayahKey) async {
    final current = state[ayahKey];
    final next = (current ?? AyahAnnotation(ayahKey: ayahKey, bookmarked: false))
        .copyWith(
      bookmarked: !(current?.bookmarked ?? false),
      updatedAt: DateTime.now(),
    );
    await _upsert(next);
  }

  Future<void> setNote(String ayahKey, String note) async {
    final current = state[ayahKey];
    final trimmed = note.trim();
    final next = (current ??
            AyahAnnotation(ayahKey: ayahKey, bookmarked: false, note: ''))
        .copyWith(
      note: trimmed,
      updatedAt: DateTime.now(),
    );
    // Drop empty non-bookmark entries.
    if (!next.bookmarked && !next.hasNote) {
      final copy = Map<String, AyahAnnotation>.from(state)..remove(ayahKey);
      state = copy;
      await _library.saveAll(copy);
      return;
    }
    await _upsert(next);
  }

  Future<void> _upsert(AyahAnnotation annotation) async {
    if (!annotation.bookmarked && !annotation.hasNote) {
      final copy = Map<String, AyahAnnotation>.from(state)
        ..remove(annotation.ayahKey);
      state = copy;
      await _library.saveAll(copy);
      return;
    }
    final copy = Map<String, AyahAnnotation>.from(state)
      ..[annotation.ayahKey] = annotation;
    state = copy;
    await _library.saveAll(copy);
  }

  List<AyahAnnotation> get bookmarks {
    final list = state.values.where((a) => a.bookmarked).toList();
    list.sort((a, b) {
      final aParts = a.ayahKey.split(':');
      final bParts = b.ayahKey.split(':');
      final as = int.parse(aParts[0]);
      final bs = int.parse(bParts[0]);
      if (as != bs) return as.compareTo(bs);
      return int.parse(aParts[1]).compareTo(int.parse(bParts[1]));
    });
    return list;
  }

  List<AyahAnnotation> get notes {
    final list = state.values.where((a) => a.hasNote).toList();
    list.sort((a, b) {
      final at = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return list;
  }
}

final userLibraryProvider =
    StateNotifierProvider<UserLibraryNotifier, Map<String, AyahAnnotation>>(
        (ref) {
  return UserLibraryNotifier(
    UserLibrary(ref.watch(sharedPreferencesProvider)),
  );
});
