#!/usr/bin/env python3
"""
Reconstruct iabotwatch db .txt files for missing days using TSS API data.

TSS (Tarb Stats Server) at https://tss.toolforge.org has per-wiki daily
aggregates for the eventstreams source (2019+). This script fetches that
data and generates synthetic .txt files in the iabotwatch db format.

Output format matches what makehtml.awk expects:
  wiki page_id iabot_wayback iabot_details other_details user_wayback otherbot_wayback iabot_sim

The page_id is set to 0 (synthetic -- no per-article granularity available from TSS).
The .details.txt and .userbots.txt drill-down files are NOT reconstructed.

Usage:
  ./tss_reconstruct.py                    # default: 2026, days 029-160
  ./tss_reconstruct.py --from 2026-01-29 --to 2026-06-09
  ./tss_reconstruct.py --dry-run          # show what would be written, no files created
"""

import urllib.request
import urllib.error
import json
import os
import sys
import argparse
from datetime import date, timedelta

TSS_BASE  = "https://tss.toolforge.org/api/v1"
DB_BASE   = "/home/greenc/toolforge/iabotwatch/www/db"

# TSS metric slug -> 0-based index into the 6-value output list
# .txt line format: wiki page_id c0 c1 c2 c3 c4 c5
#   c0 = col _a[3] = IABot web       = iabot_wayback
#   c1 = col _a[4] = IABot details   = iabot_details
#   c2 = col _a[5] = User details    = other_details
#   c3 = col _a[6] = User web        = user_wayback
#   c4 = col _a[7] = User web bot    = otherbot_wayback
#   c5 = col _a[8] = IABot sim       = iabot_sim
METRICS = [
    ("iabot_wayback",    0),
    ("iabot_details",    1),
    ("other_details",    2),
    ("user_wayback",     3),
    ("otherbot_wayback", 4),
    ("iabot_sim",        5),
]


def day_of_year(d):
    return d.timetuple().tm_yday


def fetch_grid(metric, from_date, to_date):
    url = (f"{TSS_BASE}/grid?source=eventstreams&metric={metric}"
           f"&grain=day&from={from_date}&to={to_date}")
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            return json.loads(r.read())
    except urllib.error.URLError as e:
        sys.exit(f"ERROR fetching {metric}: {e}")


def main():
    parser = argparse.ArgumentParser(description="Reconstruct iabotwatch db from TSS")
    parser.add_argument("--from", dest="from_date", default="2026-01-29",
                        help="Start date YYYY-MM-DD (default: 2026-01-29 = day 029)")
    parser.add_argument("--to",   dest="to_date",   default="2026-06-09",
                        help="End date YYYY-MM-DD   (default: 2026-06-09 = day 160)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would be written without creating files")
    args = parser.parse_args()

    from_date = date.fromisoformat(args.from_date)
    to_date   = date.fromisoformat(args.to_date)

    print(f"Range: {from_date} (day {day_of_year(from_date):03d}) "
          f"to {to_date} (day {day_of_year(to_date):03d})")
    if args.dry_run:
        print("DRY RUN — no files will be written\n")

    # Build: date_str -> wiki -> [c0, c1, c2, c3, c4, c5]
    data = {}

    for metric, col_idx in METRICS:
        print(f"  Fetching {metric}...", flush=True)
        grid = fetch_grid(metric, from_date, to_date)
        buckets = grid["buckets"]
        for row in grid["rows"]:
            wiki = row["entity"]
            for bi, val in enumerate(row["values"]):
                if not val:
                    continue
                d = buckets[bi]
                if d not in data:
                    data[d] = {}
                if wiki not in data[d]:
                    data[d][wiki] = [0] * 6
                data[d][wiki][col_idx] += val

    print()
    written = skipped = empty = 0
    current = from_date
    while current <= to_date:
        year     = current.year
        doy      = f"{day_of_year(current):03d}"
        date_str = str(current)
        db_dir   = os.path.join(DB_BASE, str(year))
        out_path = os.path.join(db_dir, f"{doy}.txt")

        if os.path.exists(out_path):
            print(f"  SKIP  {doy} ({date_str}) — file already exists")
            skipped += 1
            current += timedelta(days=1)
            continue

        day_data = data.get(date_str, {})
        if not day_data:
            print(f"  EMPTY {doy} ({date_str}) — no TSS data")
            empty += 1
            current += timedelta(days=1)
            continue

        lines = [
            f"{wiki} 0 {c[0]} {c[1]} {c[2]} {c[3]} {c[4]} {c[5]}\n"
            for wiki, c in sorted(day_data.items())
            if any(c)
        ]

        print(f"  WRITE {doy} ({date_str}) — {len(lines)} wikis")
        written += 1

        if not args.dry_run:
            os.makedirs(db_dir, exist_ok=True)
            with open(out_path, "w") as f:
                f.writelines(lines)

        current += timedelta(days=1)

    print(f"\nDone: {written} written, {skipped} skipped (exist), {empty} empty (no TSS data)")


if __name__ == "__main__":
    main()
