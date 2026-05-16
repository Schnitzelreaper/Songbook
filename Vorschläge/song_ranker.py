#!/usr/bin/env python3
"""
Song Ranker mit Kategorien.

Format der Input-Datei:
  <kategorie-kürzel> <songname>
  z.B.:
    e Thank You
    e Torn
    d 99 Luftballons
    c Bella Ciao

Duelle nur innerhalb derselben Kategorie.
Output: ein Ranking pro Kategorie.
Fortschritt wird per JSON gespeichert und beim nächsten Start fortgesetzt.
"""

import sys
import random
import os
import json
from itertools import combinations
from collections import defaultdict


# ─── Laden ────────────────────────────────────────────────────────────────────

def load_songs(filepath: str) -> dict[str, list[str]]:
    """Gibt {kategorie: [song, ...]} zurück."""
    categories: dict[str, list[str]] = defaultdict(list)
    with open(filepath, "r", encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            parts = line.split(None, 1)
            if len(parts) < 2:
                print(f"  ⚠️  Zeile {lineno} übersprungen (kein Kürzel?): '{line}'")
                continue
            cat, song = parts[0].lower(), parts[1].strip()
            categories[cat].append(song)

    if not categories:
        print("Keine Songs gefunden. Prüf das Dateiformat.")
        sys.exit(1)

    solo = [cat for cat, songs in list(categories.items()) if len(songs) < 2]
    for cat in solo:
        print(f"  ⚠️  Kategorie '{cat}' hat nur 1 Song – wird übersprungen.")
        del categories[cat]

    if not categories:
        print("Keine Kategorie mit mindestens 2 Songs. Nix zu tun.")
        sys.exit(1)

    return dict(categories)


# ─── State ────────────────────────────────────────────────────────────────────

def state_path(output_path: str) -> str:
    base, _ = os.path.splitext(output_path)
    return base + "_state.json"


def save_state(stats: dict, remaining_pairs: dict, output_path: str):
    data = {"stats": stats, "remaining_pairs": remaining_pairs}
    with open(state_path(output_path), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def load_state(output_path: str) -> tuple[dict, dict] | None:
    path = state_path(output_path)
    if not os.path.isfile(path):
        return None
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    stats = data["stats"]
    remaining = data["remaining_pairs"]
    # Altes Format: remaining_pairs war eine flache Liste statt Dict -> verwerfen
    if isinstance(remaining, list):
        print("  ⚠️  Alter State erkannt – wird zurückgesetzt.")
        return None
    return stats, remaining


# ─── Paare aufbauen ───────────────────────────────────────────────────────────

def build_pairs(categories: dict[str, list[str]]) -> dict[str, list[list[str]]]:
    result = {}
    for cat, songs in categories.items():
        pairs = [list(p) for p in combinations(songs, 2)]
        random.shuffle(pairs)
        result[cat] = pairs
    return result


def merge_with_existing(
    categories: dict[str, list[str]],
    saved_stats: dict,
    saved_remaining: dict,
) -> tuple[dict, dict]:
    stats = saved_stats

    for cat, songs in categories.items():
        if cat not in stats:
            stats[cat] = {}
        for song in songs:
            if song not in stats[cat]:
                stats[cat][song] = {"wins": 0, "losses": 0}
                print(f"  ➕ Neuer Song in [{cat}]: {song}")

        if cat not in saved_remaining:
            saved_remaining[cat] = []

        existing_set = {(a, b) for a, b in saved_remaining[cat]}
        existing_set |= {(b, a) for a, b in saved_remaining[cat]}

        new_pairs = []
        for p in combinations(songs, 2):
            if p not in existing_set:
                a_played = stats[cat].get(p[0], {}).get("wins", 0) + stats[cat].get(p[0], {}).get("losses", 0) > 0
                b_played = stats[cat].get(p[1], {}).get("wins", 0) + stats[cat].get(p[1], {}).get("losses", 0) > 0
                if not (a_played and b_played):
                    new_pairs.append(list(p))

        if new_pairs:
            random.shuffle(new_pairs)
            saved_remaining[cat].extend(new_pairs)
            print(f"  ➕ {len(new_pairs)} neue Duelle in [{cat}] ergänzt.")

    return stats, saved_remaining


# ─── Tournament ───────────────────────────────────────────────────────────────

def winrate(entry: dict) -> float:
    total = entry["wins"] + entry["losses"]
    return entry["wins"] / total if total else 0.0


def run_tournament(categories: dict[str, list[str]], output_path: str) -> dict:
    existing = load_state(output_path)

    if existing:
        saved_stats, remaining_pairs = merge_with_existing(categories, *existing)
        stats = saved_stats
        total_done = sum(
            len(list(combinations(songs, 2))) - len(remaining_pairs.get(cat, []))
            for cat, songs in categories.items()
        )
        print(f"\n▶️  Fortschritt gefunden! {total_done} Duelle bereits erledigt.")
    else:
        stats = {cat: {song: {"wins": 0, "losses": 0} for song in songs}
                 for cat, songs in categories.items()}
        remaining_pairs = build_pairs(categories)

    # Nur Kategorien berücksichtigen die gerade aktiv sind
    active_remaining = {cat: remaining_pairs[cat] for cat in categories if cat in remaining_pairs}

    total_all = sum(len(list(combinations(songs, 2))) for songs in categories.values())
    total_left = sum(len(p) for p in active_remaining.values())

    print(f"\n🎵 {sum(len(s) for s in categories.values())} Songs in {len(categories)} Kategorie(n)")
    print(f"   Noch {total_left} von {total_all} Duellen übrig!\n")
    print("Tippe 1 oder 2. 'q' zum Abbrechen.\n")
    print("─" * 50)

    done_now = total_all - total_left

    for cat in list(active_remaining.keys()):
        if not active_remaining[cat]:
            continue

        cat_total = len(list(combinations(categories[cat], 2)))
        cat_done = cat_total - len(active_remaining[cat])

        print(f"\n{'═' * 50}")
        print(f"  Kategorie: [{cat.upper()}]  –  {cat_done}/{cat_total} erledigt")
        print(f"{'═' * 50}")

        while active_remaining[cat]:
            song_a, song_b = active_remaining[cat][0]
            done_now += 1
            print(f"\nDuell {done_now}/{total_all}  [{cat.upper()}]")
            print(f"  [1] {song_a}")
            print(f"  [2] {song_b}")

            while True:
                choice = input("  Dein Pick: ").strip().lower()
                if choice == "1":
                    stats[cat][song_a]["wins"] += 1
                    stats[cat][song_b]["losses"] += 1
                    print(f"  ✅ {song_a} gewinnt!")
                    active_remaining[cat].pop(0)
                    remaining_pairs[cat] = active_remaining[cat]
                    save_state(stats, remaining_pairs, output_path)
                    break
                elif choice == "2":
                    stats[cat][song_b]["wins"] += 1
                    stats[cat][song_a]["losses"] += 1
                    print(f"  ✅ {song_b} gewinnt!")
                    active_remaining[cat].pop(0)
                    remaining_pairs[cat] = active_remaining[cat]
                    save_state(stats, remaining_pairs, output_path)
                    break
                elif choice == "q":
                    print("\n⛔ Abgebrochen. Fortschritt gespeichert.")
                    return stats
                else:
                    print("  Nur 1, 2 oder q – komm schon.")

    print("\n" + "─" * 50)
    print("🏁 Alle Duelle dieser Kategorie(n) durch!")

    # State-Datei nur löschen wenn wirklich alles erledigt ist
    all_done = all(len(v) == 0 for v in remaining_pairs.values())
    sp = state_path(output_path)
    if all_done and os.path.isfile(sp):
        os.remove(sp)
        print("🗑️  State-Datei gelöscht (alles fertig).")

    return stats


# ─── Output ───────────────────────────────────────────────────────────────────

def save_results(stats: dict, output_path: str):
    cat_names = sorted(stats.keys())

    lines_console = []
    lines_file = ["# Song Ranking nach Kategorien\n"]

    for cat in cat_names:
        entries = stats[cat]
        ranked = sorted(entries.items(), key=lambda x: (winrate(x[1]), x[1]["wins"]), reverse=True)

        header = f"\n── Kategorie [{cat.upper()}] {'─' * (40 - len(cat))}"
        col_header = f"  {'Rang':<5} {'Song':<40} {'Winrate':>8}  W / L"
        sep = "  " + "─" * 60

        lines_console.append(header)
        lines_console.append(col_header)
        lines_console.append(sep)
        lines_file.append(header + "\n")
        lines_file.append(col_header + "\n")
        lines_file.append(sep + "\n")

        for rank, (song, s) in enumerate(ranked, 1):
            wr = winrate(s)
            row = f"  {rank:<5} {song:<40} {wr:>7.1%}  {s['wins']} / {s['losses']}"
            lines_console.append(row)
            lines_file.append(row + "\n")

    print("\n")
    print("\n".join(lines_console))

    with open(output_path, "w", encoding="utf-8") as f:
        f.writelines(lines_file)

    print(f"\n💾 Ranking gespeichert in: {output_path}")


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    import argparse

    parser = argparse.ArgumentParser(description="Song Ranker mit Kategorien")
    parser.add_argument("input",           help="Song-Liste (txt)")
    parser.add_argument("output", nargs="?", default="ranking.txt", help="Output-Datei (default: ranking.txt)")
    parser.add_argument("--cat", nargs="+", help="Nur diese Kategorie(n) spielen, z.B. --cat e d")
    args = parser.parse_args()

    input_file = args.input
    if not os.path.isfile(input_file):
        print(f"Datei nicht gefunden: {input_file}")
        sys.exit(1)

    output_file = args.output

    all_categories = load_songs(input_file)

    # Kategorie-Filter anwenden
    if args.cat:
        wanted = [c.lower() for c in args.cat]
        unknown = [c for c in wanted if c not in all_categories]
        if unknown:
            print(f"  ⚠️  Unbekannte Kategorie(n): {', '.join(unknown)}")
            print(f"  Verfügbar: {', '.join(sorted(all_categories.keys()))}")
            sys.exit(1)
        categories = {c: all_categories[c] for c in wanted}
        print(f"  🎯 Nur Kategorie(n): {', '.join(c.upper() for c in wanted)}")
    else:
        categories = all_categories

    stats = run_tournament(categories, output_file)
    save_results(stats, output_file)


if __name__ == "__main__":
    main()
