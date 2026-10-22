#!/usr/bin/env python3
"""Build offline quran.sqlite and tafsir.sqlite from public sources."""

from __future__ import annotations

import json
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB_DIR = ROOT / "assets" / "db"
FONT_DIR = ROOT / "assets" / "fonts"
CACHE = ROOT / "tool" / ".cache"

UA = {"User-Agent": "quran-app-builder/1.0"}


def fetch(url: str, dest: Path | None = None, retries: int = 3) -> bytes:
    dest = dest or (CACHE / url.split("/")[-1].split("?")[0])
    if dest.exists() and dest.stat().st_size > 0:
        print(f"  cache hit: {dest.name}")
        return dest.read_bytes()
    dest.parent.mkdir(parents=True, exist_ok=True)
    last_err: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            print(f"  downloading ({attempt}/{retries}): {url}")
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=180) as resp:
                data = resp.read()
            dest.write_bytes(data)
            print(f"  saved {len(data):,} bytes -> {dest}")
            return data
        except Exception as exc:  # noqa: BLE001
            last_err = exc
            time.sleep(attempt * 2)
    raise RuntimeError(f"Failed to fetch {url}: {last_err}")


def fetch_json(url: str, dest: Path | None = None) -> object:
    return json.loads(fetch(url, dest))


SURAH_META = [
    (1, "الفاتحة", "Al-Fatihah", 7, 1),
    (2, "البقرة", "Al-Baqarah", 286, 1),
    (3, "آل عمران", "Ali 'Imran", 200, 3),
    (4, "النساء", "An-Nisa", 176, 4),
    (5, "المائدة", "Al-Ma'idah", 120, 6),
    (6, "الأنعام", "Al-An'am", 165, 7),
    (7, "الأعراف", "Al-A'raf", 206, 8),
    (8, "الأنفال", "Al-Anfal", 75, 9),
    (9, "التوبة", "At-Tawbah", 129, 10),
    (10, "يونس", "Yunus", 109, 11),
    (11, "هود", "Hud", 123, 11),
    (12, "يوسف", "Yusuf", 111, 12),
    (13, "الرعد", "Ar-Ra'd", 43, 13),
    (14, "إبراهيم", "Ibrahim", 52, 13),
    (15, "الحجر", "Al-Hijr", 99, 14),
    (16, "النحل", "An-Nahl", 128, 14),
    (17, "الإسراء", "Al-Isra", 111, 15),
    (18, "الكهف", "Al-Kahf", 110, 15),
    (19, "مريم", "Maryam", 98, 16),
    (20, "طه", "Taha", 135, 16),
    (21, "الأنبياء", "Al-Anbya", 112, 17),
    (22, "الحج", "Al-Hajj", 78, 17),
    (23, "المؤمنون", "Al-Mu'minun", 118, 18),
    (24, "النور", "An-Nur", 64, 18),
    (25, "الفرقان", "Al-Furqan", 77, 18),
    (26, "الشعراء", "Ash-Shu'ara", 227, 19),
    (27, "النمل", "An-Naml", 93, 19),
    (28, "القصص", "Al-Qasas", 88, 20),
    (29, "العنكبوت", "Al-'Ankabut", 69, 20),
    (30, "الروم", "Ar-Rum", 60, 21),
    (31, "لقمان", "Luqman", 34, 21),
    (32, "السجدة", "As-Sajdah", 30, 21),
    (33, "الأحزاب", "Al-Ahzab", 73, 21),
    (34, "سبإ", "Saba", 54, 22),
    (35, "فاطر", "Fatir", 45, 22),
    (36, "يس", "Ya-Sin", 83, 22),
    (37, "الصافات", "As-Saffat", 182, 23),
    (38, "ص", "Sad", 88, 23),
    (39, "الزمر", "Az-Zumar", 75, 23),
    (40, "غافر", "Ghafir", 85, 24),
    (41, "فصلت", "Fussilat", 54, 24),
    (42, "الشورى", "Ash-Shuraa", 53, 25),
    (43, "الزخرف", "Az-Zukhruf", 89, 25),
    (44, "الدخان", "Ad-Dukhan", 59, 25),
    (45, "الجاثية", "Al-Jathiyah", 37, 25),
    (46, "الأحقاف", "Al-Ahqaf", 35, 26),
    (47, "محمد", "Muhammad", 38, 26),
    (48, "الفتح", "Al-Fath", 29, 26),
    (49, "الحجرات", "Al-Hujurat", 18, 26),
    (50, "ق", "Qaf", 45, 26),
    (51, "الذاريات", "Adh-Dhariyat", 60, 26),
    (52, "الطور", "At-Tur", 49, 27),
    (53, "النجم", "An-Najm", 62, 27),
    (54, "القمر", "Al-Qamar", 55, 27),
    (55, "الرحمن", "Ar-Rahman", 78, 27),
    (56, "الواقعة", "Al-Waqi'ah", 96, 27),
    (57, "الحديد", "Al-Hadid", 29, 27),
    (58, "المجادلة", "Al-Mujadila", 22, 28),
    (59, "الحشر", "Al-Hashr", 24, 28),
    (60, "الممتحنة", "Al-Mumtahanah", 13, 28),
    (61, "الصف", "As-Saf", 14, 28),
    (62, "الجمعة", "Al-Jumu'ah", 11, 28),
    (63, "المنافقون", "Al-Munafiqun", 11, 28),
    (64, "التغابن", "At-Taghabun", 18, 28),
    (65, "الطلاق", "At-Talaq", 12, 28),
    (66, "التحريم", "At-Tahrim", 12, 28),
    (67, "الملك", "Al-Mulk", 30, 29),
    (68, "القلم", "Al-Qalam", 52, 29),
    (69, "الحاقة", "Al-Haqqah", 52, 29),
    (70, "المعارج", "Al-Ma'arij", 44, 29),
    (71, "نوح", "Nuh", 28, 29),
    (72, "الجن", "Al-Jinn", 28, 29),
    (73, "المزمل", "Al-Muzzammil", 20, 29),
    (74, "المدثر", "Al-Muddaththir", 56, 29),
    (75, "القيامة", "Al-Qiyamah", 40, 29),
    (76, "الإنسان", "Al-Insan", 31, 29),
    (77, "المرسلات", "Al-Mursalat", 50, 29),
    (78, "النبإ", "An-Naba", 40, 30),
    (79, "النازعات", "An-Nazi'at", 46, 30),
    (80, "عبس", "'Abasa", 42, 30),
    (81, "التكوير", "At-Takwir", 29, 30),
    (82, "الإنفطار", "Al-Infitar", 19, 30),
    (83, "المطففين", "Al-Mutaffifin", 36, 30),
    (84, "الإنشقاق", "Al-Inshiqaq", 25, 30),
    (85, "البروج", "Al-Buruj", 22, 30),
    (86, "الطارق", "At-Tariq", 17, 30),
    (87, "الأعلى", "Al-A'la", 19, 30),
    (88, "الغاشية", "Al-Ghashiyah", 26, 30),
    (89, "الفجر", "Al-Fajr", 30, 30),
    (90, "البلد", "Al-Balad", 20, 30),
    (91, "الشمس", "Ash-Shams", 15, 30),
    (92, "الليل", "Al-Layl", 21, 30),
    (93, "الضحى", "Ad-Duhaa", 11, 30),
    (94, "الشرح", "Ash-Sharh", 8, 30),
    (95, "التين", "At-Tin", 8, 30),
    (96, "العلق", "Al-'Alaq", 19, 30),
    (97, "القدر", "Al-Qadr", 5, 30),
    (98, "البينة", "Al-Bayyinah", 8, 30),
    (99, "الزلزلة", "Az-Zalzalah", 8, 30),
    (100, "العاديات", "Al-'Adiyat", 11, 30),
    (101, "القارعة", "Al-Qari'ah", 11, 30),
    (102, "التكاثر", "At-Takathur", 8, 30),
    (103, "العصر", "Al-'Asr", 3, 30),
    (104, "الهمزة", "Al-Humazah", 9, 30),
    (105, "الفيل", "Al-Fil", 5, 30),
    (106, "قريش", "Quraysh", 4, 30),
    (107, "الماعون", "Al-Ma'un", 7, 30),
    (108, "الكوثر", "Al-Kawthar", 3, 30),
    (109, "الكافرون", "Al-Kafirun", 6, 30),
    (110, "النصر", "An-Nasr", 3, 30),
    (111, "المسد", "Al-Masad", 5, 30),
    (112, "الإخلاص", "Al-Ikhlas", 4, 30),
    (113, "الفلق", "Al-Falaq", 5, 30),
    (114, "الناس", "An-Nas", 6, 30),
]


def build_quran_db(path: Path) -> None:
    print("Building quran.sqlite...")
    if path.exists():
        path.unlink()
    conn = sqlite3.connect(path)
    cur = conn.cursor()
    cur.executescript(
        """
        CREATE TABLE surahs (
          number INTEGER PRIMARY KEY,
          name_ar TEXT NOT NULL,
          name_en TEXT NOT NULL,
          ayah_count INTEGER NOT NULL,
          revelation_order INTEGER
        );
        CREATE TABLE ayahs (
          id INTEGER PRIMARY KEY,
          surah INTEGER NOT NULL,
          ayah INTEGER NOT NULL,
          text TEXT NOT NULL,
          page INTEGER NOT NULL,
          juz INTEGER NOT NULL,
          UNIQUE(surah, ayah)
        );
        CREATE INDEX idx_ayahs_page ON ayahs(page);
        CREATE INDEX idx_ayahs_surah ON ayahs(surah);
        """
    )
    cur.executemany(
        "INSERT INTO surahs(number, name_ar, name_en, ayah_count, revelation_order) VALUES (?,?,?,?,?)",
        [(n, ar, en, count, None) for n, ar, en, count, _juz in SURAH_META],
    )

    # Uthmani text from quran-json
    quran = fetch_json(
        "https://cdn.jsdelivr.net/npm/quran-json@3.1.2/dist/quran.json",
        CACHE / "quran.json",
    )
    # Page/juz from quran.com metadata via verses endpoint (page map)
    page_map: dict[str, tuple[int, int]] = {}
    for chapter in range(1, 115):
        data = fetch_json(
            f"https://api.quran.com/api/v4/verses/by_chapter/{chapter}"
            f"?fields=text_uthmani,page_number,juz_number&per_page=300",
            CACHE / f"verses_ch_{chapter}.json",
        )
        for v in data["verses"]:
            key = v["verse_key"]
            page_map[key] = (int(v["page_number"]), int(v["juz_number"]))
        time.sleep(0.05)

    ayah_id = 0
    rows = []
    for surah in quran:
        snum = int(surah["id"])
        for verse in surah["verses"]:
            anum = int(verse["id"])
            key = f"{snum}:{anum}"
            page, juz = page_map[key]
            ayah_id += 1
            rows.append((ayah_id, snum, anum, verse["text"], page, juz))
    cur.executemany(
        "INSERT INTO ayahs(id, surah, ayah, text, page, juz) VALUES (?,?,?,?,?,?)",
        rows,
    )
    conn.commit()
    conn.close()
    print(f"  wrote {ayah_id} ayahs -> {path}")


def normalize_tafsir_text(text: object) -> str:
    if text is None:
        return ""
    if isinstance(text, list):
        return "\n\n".join(normalize_tafsir_text(t) for t in text if t)
    if isinstance(text, dict):
        # common shapes
        for k in ("text", "tafsir", "body", "content"):
            if k in text:
                return normalize_tafsir_text(text[k])
        return json.dumps(text, ensure_ascii=False)
    return str(text).strip()


def insert_edition(cur: sqlite3.Cursor, edition_id: int, slug: str, name: str, language: str, rows: list[tuple]) -> None:
    cur.execute(
        "INSERT INTO editions(id, slug, name, language) VALUES (?,?,?,?)",
        (edition_id, slug, name, language),
    )
    payload = [
        (edition_id, key, group, from_a, to_a, text)
        for key, group, from_a, to_a, text in rows
    ]
    cur.executemany(
        """
        INSERT INTO tafsir(edition_id, ayah_key, group_ayah_key, from_ayah, to_ayah, text)
        VALUES (?,?,?,?,?,?)
        """,
        payload,
    )
    print(f"  edition {slug}: {len(rows)} rows")


def rows_from_ayah_map(data: dict) -> list[tuple]:
    """Convert QUL-like {ayah_key: {text, ayah_keys}|pointer} or flat maps."""
    rows: list[tuple] = []
    for key, value in data.items():
        if not isinstance(key, str) or ":" not in key:
            continue
        if isinstance(value, str) and ":" in value and len(value) < 12:
            # pointer to group
            rows.append((key, value, key, key, ""))
            continue
        if isinstance(value, dict):
            text = normalize_tafsir_text(value.get("text", value))
            keys = value.get("ayah_keys") or [key]
            if isinstance(keys, str):
                keys = [k.strip() for k in keys.split(",") if k.strip()]
            group = keys[0] if keys else key
            from_a = keys[0] if keys else key
            to_a = keys[-1] if keys else key
            rows.append((key, group, from_a, to_a, text if key == group else ""))
            continue
        text = normalize_tafsir_text(value)
        if text:
            rows.append((key, key, key, key, text))
    return rows


def load_islamic_app(slug: str) -> list[tuple]:
    raw = fetch_json(
        f"https://api.islamic.app/v1/quran/tafsirs/{slug}",
        CACHE / f"islamic_{slug}.json",
    )
    rows: list[tuple] = []
    # Shape: {code, data: {edition, ayahs: [{verse_key, text}]}}
    items: object
    if isinstance(raw, dict):
        data = raw.get("data", raw)
        if isinstance(data, dict) and "ayahs" in data:
            items = data["ayahs"]
        elif "tafsirs" in raw:
            items = raw["tafsirs"]
        elif isinstance(data, list):
            items = data
        elif isinstance(data, dict):
            return rows_from_ayah_map(data)
        else:
            return rows_from_ayah_map(raw)
    else:
        items = raw

    if isinstance(items, dict):
        return rows_from_ayah_map(items)

    for item in items:
        if not isinstance(item, dict):
            continue
        surah = item.get("surah") or item.get("chapter") or item.get("sura")
        ayah = item.get("ayah") or item.get("verse") or item.get("aya")
        key = item.get("ayah_key") or item.get("verse_key")
        if key is None and surah is not None and ayah is not None:
            key = f"{int(surah)}:{int(ayah)}"
        if not key:
            continue
        text = normalize_tafsir_text(
            item.get("text") or item.get("tafsir") or item.get("body")
        )
        group = item.get("group_ayah_key") or key
        from_a = item.get("from_ayah") or item.get("group_verse_key_from") or key
        to_a = item.get("to_ayah") or item.get("group_verse_key_to") or key
        if text:
            rows.append((key, group, from_a, to_a, text))
    return rows


def load_nwv_edition(slug: str) -> list[tuple]:
    rows: list[tuple] = []
    for surah in range(1, 115):
        url = (
            "https://cdn.jsdelivr.net/gh/fauwadwali-oss/nwv-islamic-data@main/"
            f"tafsir/{slug}/{surah}.json"
        )
        try:
            data = fetch_json(url, CACHE / "nwv" / slug / f"{surah}.json")
        except Exception as exc:  # noqa: BLE001
            print(f"  warn: skip {slug}/{surah}: {exc}")
            continue
        if isinstance(data, list):
            for item in data:
                anum = int(item.get("ayah") or item.get("ayah_number") or item.get("number"))
                text = normalize_tafsir_text(item.get("text") or item.get("tafsir"))
                key = f"{surah}:{anum}"
                if text:
                    rows.append((key, key, key, key, text))
        elif isinstance(data, dict):
            if "ayahs" in data or "verses" in data:
                for item in data.get("ayahs") or data.get("verses"):
                    anum = int(item.get("ayah") or item.get("ayah_number") or item.get("number"))
                    text = normalize_tafsir_text(item.get("text") or item.get("tafsir"))
                    key = f"{surah}:{anum}"
                    if text:
                        rows.append((key, key, key, key, text))
            else:
                for k, v in data.items():
                    if str(k).isdigit():
                        key = f"{surah}:{int(k)}"
                        text = normalize_tafsir_text(v)
                        if text:
                            rows.append((key, key, key, key, text))
                    elif ":" in str(k):
                        text = normalize_tafsir_text(v)
                        if text:
                            rows.append((str(k), str(k), str(k), str(k), text))
        time.sleep(0.02)
    return rows


def load_spa5k_edition(slug: str) -> list[tuple]:
    """Load surah aggregate JSON arrays from spa5k/tafsir_api (jsDelivr, then GitHub raw)."""
    rows: list[tuple] = []
    for surah in range(1, 115):
        cache_path = CACHE / "spa5k" / slug / f"{surah}.json"
        urls = [
            f"https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/{slug}/{surah}.json",
            f"https://raw.githubusercontent.com/spa5k/tafsir_api/main/tafsir/{slug}/{surah}.json",
        ]
        data = None
        for url in urls:
            try:
                data = fetch_json(url, cache_path)
                break
            except Exception as exc:  # noqa: BLE001
                print(f"  warn: {slug}/{surah} via {url.split('/')[2]}: {exc}")
                # allow retry with alternate host; delete empty/partial cache
                if cache_path.exists() and cache_path.stat().st_size < 10:
                    cache_path.unlink()
        if data is None:
            continue
        if isinstance(data, list):
            for item in data:
                if not isinstance(item, dict):
                    continue
                anum = int(item.get("ayah") or item.get("number") or 0)
                snum = int(item.get("surah") or surah)
                if anum <= 0:
                    continue
                text = normalize_tafsir_text(item.get("text"))
                key = f"{snum}:{anum}"
                if text:
                    rows.append((key, key, key, key, text))
        time.sleep(0.05)
        if surah % 20 == 0:
            print(f"  spa5k {slug}: surah {surah}, rows so far {len(rows)}")
    return rows


def build_tafsir_db(path: Path) -> None:
    print("Building tafsir.sqlite...")
    if path.exists():
        path.unlink()
    conn = sqlite3.connect(path)
    cur = conn.cursor()
    cur.executescript(
        """
        CREATE TABLE editions (
          id INTEGER PRIMARY KEY,
          slug TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          language TEXT NOT NULL
        );
        CREATE TABLE tafsir (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          edition_id INTEGER NOT NULL,
          ayah_key TEXT NOT NULL,
          group_ayah_key TEXT NOT NULL,
          from_ayah TEXT NOT NULL,
          to_ayah TEXT NOT NULL,
          text TEXT NOT NULL,
          FOREIGN KEY(edition_id) REFERENCES editions(id)
        );
        CREATE INDEX idx_tafsir_lookup ON tafsir(edition_id, ayah_key);
        CREATE INDEX idx_tafsir_group ON tafsir(edition_id, group_ayah_key);
        """
    )

    print("Loading Ibn Kathir Arabic...")
    ik_ar = load_islamic_app("ar-tafsir-ibn-kathir")
    insert_edition(cur, 1, "ar-ibn-kathir", "Tafsir Ibn Kathir", "ar", ik_ar)

    print("Loading Ibn Kathir English (abridged)...")
    ik_en = load_islamic_app("en-tafisr-ibn-kathir")
    insert_edition(
        cur, 2, "en-ibn-kathir", "Tafsir Ibn Kathir (Abridged)", "en", ik_en
    )

    print("Loading Jalalayn English (nwv)...")
    jal_en = load_nwv_edition("en-al-jalalayn")
    if not jal_en:
        print("  fallback: spa5k en-al-jalalayn")
        jal_en = load_spa5k_edition("en-al-jalalayn")
    insert_edition(cur, 3, "en-jalalayn", "Tafsir al-Jalalayn", "en", jal_en)

    print("Loading Jalalayn Arabic (spa5k)...")
    jal_ar = load_spa5k_edition("ar-tafsir-al-jalalayn")
    insert_edition(cur, 4, "ar-jalalayn", "تفسير الجلالين", "ar", jal_ar)

    print("Loading Mukhtasar Arabic (spa5k)...")
    muk_ar = load_spa5k_edition("ar-tafsir-al-mukhtasar")
    insert_edition(cur, 5, "ar-mukhtasar", "التفسير المختصر", "ar", muk_ar)

    print("Loading Mukhtasar English (spa5k)...")
    muk_en = load_spa5k_edition("en-tafsir-al-mukhtasar")
    insert_edition(cur, 6, "en-mukhtasar", "Al-Mukhtasar (English)", "en", muk_en)

    conn.commit()
    conn.close()
    print(f"  wrote tafsir db -> {path}")


def download_font() -> None:
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    dest = FONT_DIR / "UthmanicHafs.ttf"
    if dest.exists() and dest.stat().st_size > 1000:
        print(f"Font exists: {dest}")
        return
    candidates = [
        "https://raw.githubusercontent.com/google/fonts/main/ofl/scheherazadenew/ScheherazadeNew-Regular.ttf",
        "https://raw.githubusercontent.com/googlefonts/scheherazade/main/fonts/ttf/ScheherazadeNew-Regular.ttf",
        "https://raw.githubusercontent.com/rastikerdar/vazirmatn/master/fonts/ttf/Vazirmatn-Regular.ttf",
    ]
    for url in candidates:
        try:
            data = fetch(url, CACHE / Path(url).name)
            dest.write_bytes(data)
            print(f"Font saved from {url}")
            return
        except Exception as exc:  # noqa: BLE001
            print(f"  font candidate failed: {exc}")
    raise RuntimeError("Could not download an Arabic font")


def main() -> int:
    DB_DIR.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    download_font()
    build_quran_db(DB_DIR / "quran.sqlite")
    build_tafsir_db(DB_DIR / "tafsir.sqlite")
    print("Done.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except urllib.error.URLError as exc:
        print(f"Network error: {exc}", file=sys.stderr)
        raise
