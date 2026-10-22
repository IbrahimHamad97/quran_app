# References & data sources

Where every bundled Quran/tafsir/font asset came from. Update this file whenever `assets/` content changes. Use these links for Play Store / open-source notices.

Build script: [`tool/build_databases.py`](tool/build_databases.py)

**Publishing note:** This app is non-commercial. Content remains attributed to the upstream projects below; this app does not claim authorship of the Quran text or tafsir works.

## Quran text (Arabic)

| Item | Source | Notes |
|------|--------|-------|
| Uthmani ayah text | [quran-json](https://cdn.jsdelivr.net/npm/quran-json@3.1.2/dist/quran.json) (`quran-json@3.1.2`) | Complete 114 surahs |
| Madani page number & juz per ayah | [Quran.com Content API v4](https://api.quran.com/api/v4/verses/by_chapter/{n}?fields=text_uthmani,page_number,juz_number&per_page=300) | Used to attach `page` / `juz` in `quran.sqlite` |
| Surah names (AR/EN) | Embedded metadata in the build script (standard Hafs names) | Stored in `surahs` table |

Output: `assets/db/quran.sqlite`

## Tafsir editions

Stored in `assets/db/tafsir.sqlite` (`editions` + `tafsir` tables).

| App slug | Name | Language | Upstream source |
|----------|------|----------|-----------------|
| `ar-ibn-kathir` | Tafsir Ibn Kathir | Arabic | [islamic.app](https://api.islamic.app/v1/quran/tafsirs/ar-tafsir-ibn-kathir) (mirrors Quran.com resource `ar-tafsir-ibn-kathir`, id 14) |
| `en-ibn-kathir` | Tafsir Ibn Kathir (Abridged) | English | [islamic.app](https://api.islamic.app/v1/quran/tafsirs/en-tafisr-ibn-kathir) (Quran.com resource `en-tafisr-ibn-kathir`, id 169). **Abridged** English edition. |
| `en-jalalayn` | Tafsir al-Jalalayn | English | [nwv-islamic-data](https://github.com/fauwadwali-oss/nwv-islamic-data) `tafsir/en-al-jalalayn/{surah}.json` via jsDelivr; fallback [spa5k/tafsir_api](https://github.com/spa5k/tafsir_api) `en-al-jalalayn` |
| `ar-jalalayn` | تفسير الجلالين | Arabic | [spa5k/tafsir_api](https://github.com/spa5k/tafsir_api) `tafsir/ar-tafsir-al-jalalayn/{surah}.json` (originally from [Tarteel QUL](https://qul.tarteel.ai/resources/tafsir)) |
| `ar-mukhtasar` | التفسير المختصر | Arabic | [spa5k/tafsir_api](https://github.com/spa5k/tafsir_api) `tafsir/ar-tafsir-al-mukhtasar/{surah}.json` (QUL Arabic Al-Mukhtasar) |
| `en-mukhtasar` | Al-Mukhtasar (English) | English | [spa5k/tafsir_api](https://github.com/spa5k/tafsir_api) `tafsir/en-tafsir-al-mukhtasar/{surah}.json` (QUL English Al-Mukhtasar, resource 266) |

Primary catalog for many of these editions: [Tarteel Quranic Universal Library (QUL) — Tafsirs](https://qul.tarteel.ai/resources/tafsir).

Tafsir text may include HTML tags (`<p>`, `<h2>`, etc.). The app renders it with `flutter_html`.

Grouped / multi-ayah passages: when an ayah row has empty `text`, the app resolves `group_ayah_key` (QUL-style grouping).

Approximate row counts after the last build (ayah keys with stored commentary):

- `ar-ibn-kathir` ≈ 6205
- `en-ibn-kathir` ≈ 1895 (abridged; many ayahs intentionally omit separate entries)
- `en-jalalayn` ≈ 5325
- `ar-jalalayn` ≈ 6000+
- `ar-mukhtasar` ≈ 6236
- `en-mukhtasar` ≈ 6161

Helper scripts: `tool/build_databases.py`, `tool/fill_jalalayn_gaps.py`

## Font

| File | Source | Notes |
|------|--------|-------|
| `assets/fonts/UthmanicHafs.ttf` | [Scheherazade New Regular](https://github.com/google/fonts/tree/main/ofl/scheherazadenew) (SIL OFL) downloaded during build | Used as the Arabic display font family `UthmanicHafs` in the app. Prefer upgrading later to an official KFGQPC Uthmanic Hafs face if redistributed under compatible terms. |

## Tools & libraries (runtime)

- Flutter / Dart SDK
- `sqflite`, `path_provider` — local SQLite
- `flutter_riverpod` — state
- `go_router` — navigation
- `shared_preferences` — theme, zoom, last-read
- `flutter_html` — tafsir HTML

## Attribution reminder

When distributing builds, keep this file (or equivalent credits) with the app. Do not present upstream tafsir/Quran data as original authorship of this project.
