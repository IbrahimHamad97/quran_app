#!/usr/bin/env python3
"""Fill missing ar-jalalayn surahs after CDN 403 gaps."""

from __future__ import annotations

import json
import sqlite3
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "tool" / ".cache" / "spa5k" / "ar-tafsir-al-jalalayn"
DB = ROOT / "assets" / "db" / "tafsir.sqlite"
QURAN = ROOT / "assets" / "db" / "quran.sqlite"
UA = {"User-Agent": "quran-app-builder/1.0"}


def fetch(surah: int):
    dest = CACHE / f"{surah}.json"
    if dest.exists() and dest.stat().st_size > 20:
        return json.loads(dest.read_text(encoding="utf-8"))
    for url in [
        f"https://raw.githubusercontent.com/spa5k/tafsir_api/main/tafsir/ar-tafsir-al-jalalayn/{surah}.json",
        f"https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/ar-tafsir-al-jalalayn/{surah}.json",
    ]:
        try:
            req = urllib.request.Request(url, headers=UA)
            data = urllib.request.urlopen(req, timeout=120).read()
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            print(f"got {surah} {len(data)} {url.split('/')[2]}")
            return json.loads(data)
        except Exception as exc:  # noqa: BLE001
            print(f"fail {surah} {url.split('/')[2]} {exc}")
            time.sleep(1)
    return None


def main() -> None:
    conn = sqlite3.connect(DB)
    eid = conn.execute(
        "select id from editions where slug='ar-jalalayn'"
    ).fetchone()[0]
    counts = {
        s: c
        for s, c in conn.execute(
            """
            select cast(substr(ayah_key, 1, instr(ayah_key, ':') - 1) as int),
                   count(*)
            from tafsir
            where edition_id=?
            group by 1
            """,
            (eid,),
        )
    }
    q = sqlite3.connect(QURAN)
    expected = {n: c for n, c in q.execute("select number, ayah_count from surahs")}
    q.close()

    missing = [
        (s, counts.get(s, 0), expected[s])
        for s in range(1, 115)
        if counts.get(s, 0) < expected[s]
    ]
    print(f"incomplete surahs: {len(missing)}")
    added = 0
    for s, have, exp in missing:
        print(f"patching {s}: have {have} expected {exp}")
        data = fetch(s)
        if not data:
            continue
        conn.execute(
            "delete from tafsir where edition_id=? and ayah_key like ?",
            (eid, f"{s}:%"),
        )
        for item in data:
            anum = int(item["ayah"])
            text = (item.get("text") or "").strip()
            if not text:
                continue
            key = f"{s}:{anum}"
            conn.execute(
                """
                insert into tafsir(
                  edition_id, ayah_key, group_ayah_key, from_ayah, to_ayah, text
                ) values (?,?,?,?,?,?)
                """,
                (eid, key, key, key, key, text),
            )
            added += 1
        time.sleep(0.1)
    conn.commit()
    total = conn.execute(
        "select count(*) from tafsir where edition_id=?", (eid,)
    ).fetchone()[0]
    print(f"ar-jalalayn rows now {total}; wrote {added}")
    conn.close()


if __name__ == "__main__":
    main()
