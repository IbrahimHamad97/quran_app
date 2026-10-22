import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'theme_mode';
  static const _quranFontKey = 'quran_font_size';
  static const _tafsirFontKey = 'tafsir_font_size';
  static const _tafsirEditionKey = 'tafsir_edition_slug';
  static const _tafsirLangKey = 'tafsir_language';
  static const _lastSurahKey = 'last_surah';
  static const _lastAyahKey = 'last_ayah';
  static const _favoriteSurahsKey = 'favorite_surahs';

  ThemeMode get themeMode {
    switch (_prefs.getString(_themeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_themeKey, value);
  }

  double get quranFontSize => _prefs.getDouble(_quranFontKey) ?? 28;

  Future<void> setQuranFontSize(double size) =>
      _prefs.setDouble(_quranFontKey, size.clamp(18, 48));

  double get tafsirFontSize => _prefs.getDouble(_tafsirFontKey) ?? 18;

  Future<void> setTafsirFontSize(double size) =>
      _prefs.setDouble(_tafsirFontKey, size.clamp(14, 36));

  String get tafsirEditionSlug =>
      _prefs.getString(_tafsirEditionKey) ?? 'en-ibn-kathir';

  Future<void> setTafsirEditionSlug(String slug) =>
      _prefs.setString(_tafsirEditionKey, slug);

  String get tafsirLanguage => _prefs.getString(_tafsirLangKey) ?? 'en';

  Future<void> setTafsirLanguage(String lang) =>
      _prefs.setString(_tafsirLangKey, lang);

  int? get lastSurah => _prefs.getInt(_lastSurahKey);

  int? get lastAyah => _prefs.getInt(_lastAyahKey);

  Future<void> setLastRead(int surah, int ayah) async {
    await _prefs.setInt(_lastSurahKey, surah);
    await _prefs.setInt(_lastAyahKey, ayah);
  }

  List<int> get favoriteSurahs {
    final raw = _prefs.getStringList(_favoriteSurahsKey) ?? const [];
    return raw.map(int.parse).toList()..sort();
  }

  bool isFavoriteSurah(int surah) => favoriteSurahs.contains(surah);

  Future<void> setFavoriteSurahs(List<int> surahs) async {
    final unique = surahs.toSet().toList()..sort();
    await _prefs.setStringList(
      _favoriteSurahsKey,
      unique.map((n) => n.toString()).toList(),
    );
  }

  Future<void> toggleFavoriteSurah(int surah) async {
    final next = [...favoriteSurahs];
    if (next.contains(surah)) {
      next.remove(surah);
    } else {
      next.add(surah);
    }
    await setFavoriteSurahs(next);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main');
});

final appPreferencesProvider = Provider<AppPreferences>((ref) {
  return AppPreferences(ref.watch(sharedPreferencesProvider));
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs) : super(_prefs.themeMode);

  final AppPreferences _prefs;

  Future<void> setMode(ThemeMode mode) async {
    await _prefs.setThemeMode(mode);
    state = mode;
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(appPreferencesProvider));
});

class FontSizeNotifier extends StateNotifier<double> {
  FontSizeNotifier(this._prefs, this._read, this._write)
      : super(_read(_prefs));

  final AppPreferences _prefs;
  final double Function(AppPreferences) _read;
  final Future<void> Function(AppPreferences, double) _write;

  Future<void> setSize(double size) async {
    await _write(_prefs, size);
    state = _read(_prefs);
  }

  Future<void> bump(double delta) => setSize(state + delta);
}

final quranFontSizeProvider =
    StateNotifierProvider<FontSizeNotifier, double>((ref) {
  final prefs = ref.watch(appPreferencesProvider);
  return FontSizeNotifier(
    prefs,
    (p) => p.quranFontSize,
    (p, v) => p.setQuranFontSize(v),
  );
});

final tafsirFontSizeProvider =
    StateNotifierProvider<FontSizeNotifier, double>((ref) {
  final prefs = ref.watch(appPreferencesProvider);
  return FontSizeNotifier(
    prefs,
    (p) => p.tafsirFontSize,
    (p, v) => p.setTafsirFontSize(v),
  );
});

class LastRead {
  const LastRead({required this.surah, required this.ayah});

  final int surah;
  final int ayah;
}

class LastReadNotifier extends StateNotifier<LastRead?> {
  LastReadNotifier(this._prefs)
      : super(
          _prefs.lastSurah != null && _prefs.lastAyah != null
              ? LastRead(surah: _prefs.lastSurah!, ayah: _prefs.lastAyah!)
              : null,
        );

  final AppPreferences _prefs;

  Future<void> setPosition(int surah, int ayah) async {
    await _prefs.setLastRead(surah, ayah);
    state = LastRead(surah: surah, ayah: ayah);
  }
}

final lastReadProvider =
    StateNotifierProvider<LastReadNotifier, LastRead?>((ref) {
  return LastReadNotifier(ref.watch(appPreferencesProvider));
});

class FavoriteSurahsNotifier extends StateNotifier<Set<int>> {
  FavoriteSurahsNotifier(this._prefs)
      : super(_prefs.favoriteSurahs.toSet());

  final AppPreferences _prefs;

  Future<void> toggle(int surah) async {
    await _prefs.toggleFavoriteSurah(surah);
    state = _prefs.favoriteSurahs.toSet();
  }

  bool isFavorite(int surah) => state.contains(surah);
}

final favoriteSurahsProvider =
    StateNotifierProvider<FavoriteSurahsNotifier, Set<int>>((ref) {
  return FavoriteSurahsNotifier(ref.watch(appPreferencesProvider));
});
