# Quran & Tafsir

Offline Flutter app for reading the Arabic Quran with classic tafsir. All Quran text and tafsir data ship inside the app — no internet is required after install.

Intended for a personal, non-commercial Google Play release.

## Features

- Offline Arabic Quran (Uthmani text) with Madani **page** and **juz** indicators
- Continuous scrollable reader (finish a surah → next surah continues below) with zoom
- Resume progress updates only when you scroll or select an ayah (not on accidental open)
- Ayah selection highlight + action bar: **Tafsir**, **Bookmark**, **Note**, **Copy**
- Three tafsirs in Arabic and English: Ibn Kathir (English abridged), al-Jalalayn, Al-Mukhtasar
- Bookmark surahs (toast confirmation; listed under Bookmarks → Surah)
- Resume reading card on the home screen
- Search (surah name, `2:255`, `page 12`, `juz 5`, Arabic text)
- Browse by juz or Madani page
- Bookmarks & notes screen: **Surah / Ayah / Notes** tabs
- Light / Dark / System theme

## Data sources & attribution

Full URLs and edition details: **[REFERENCES.md](REFERENCES.md)** — check these before Play Store listing / open-source notices.

| Content | Upstream |
|---------|----------|
| Quran text | [quran-json](https://www.npmjs.com/package/quran-json) |
| Page / juz metadata | [api.quran.com](https://api.quran.com) |
| Ibn Kathir AR/EN | [islamic.app](https://api.islamic.app) (Quran.com-backed editions) |
| Jalalayn / Mukhtasar | [spa5k/tafsir_api](https://github.com/spa5k/tafsir_api), [nwv-islamic-data](https://github.com/fauwadwali-oss/nwv-islamic-data) (from [Tarteel QUL](https://qul.tarteel.ai/resources/tafsir)) |
| Arabic font | [Scheherazade New](https://github.com/google/fonts/tree/main/ofl/scheherazadenew) (SIL OFL) |

## Run

```bash
flutter pub get
flutter run
```

Release smoke test on a phone:

```bash
flutter run --release
```

Rebuild SQLite assets (optional):

```bash
python tool/build_databases.py
```

## Future ideas

- Reading goals / daily streak
- Keep screen on while reading
- Stronger resume highlight animation
- Optional offline audio
- Home-screen widget

## Project layout

```text
lib/features/   # surah_list, reader, search, browse, bookmarks, tafsir, settings
assets/db/      # quran.sqlite, tafsir.sqlite
assets/fonts/
REFERENCES.md
PLAY_STORE.md
```
