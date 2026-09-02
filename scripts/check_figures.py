"""
Verify every documented figure against the warehouse that produced it.

Project 1 binds the figures in its README to its output CSVs with test_docs.py.
This project, whose whole argument is documentation bound to reality, had
hand-typed numbers in every model header with nothing checking them. An external
reviewer found one that was wrong: stg_geolocation.sql claimed its output was
19,015 rows when 19,015 is the RAW distinct count and its actual output is
19,011. A second one had gone stale the same way, unnoticed, when the bounding
box changed.

Two checks per figure, and they catch different failures:

  1. The claim still matches the query. Catches a figure that went stale because
     a model changed underneath it.
  2. Every file listed in `cited_in` actually contains the number. Catches a
     figure that was edited in one place and not the others, and catches a
     `cited_in` entry that has quietly become fiction.

Run after `dbt build`. Exits non-zero on any mismatch.
"""

import re
import sys
from pathlib import Path

import duckdb
import yaml

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "data" / "olist.duckdb"
FIGURES = ROOT / "docs" / "figures.yml"


def formats(n: int) -> list[str]:
    """The spellings a number may legitimately appear as in prose."""
    return list(dict.fromkeys([f"{n:,}", str(n)]))


def cited(path: Path, n: int) -> bool:
    """True if the file quotes the number, in any accepted spelling.

    Bare digits must not match inside a longer number: '19011' should not be
    satisfied by '190110', and '13' should not be satisfied by '132'.
    """
    text = path.read_text()
    for form in formats(n):
        if re.search(rf"(?<![\d,.]){re.escape(form)}(?![\d,])", text):
            return True
    return False


def main() -> int:
    if not DB.exists():
        print(f"ERROR: {DB} not found. Run scripts/load_raw.py and dbt build first.")
        return 1

    spec = yaml.safe_load(FIGURES.read_text())
    con = duckdb.connect(str(DB), read_only=True)

    failures = []
    for fig in spec["figures"]:
        name, claim = fig["name"], fig["claim"]

        actual = con.execute(fig["sql"]).fetchone()[0]
        if actual != claim:
            failures.append(
                f"{name}: documented {claim:,} but the warehouse says {actual:,}\n"
                f"    {fig['sql'].strip()}"
            )
            continue

        for rel in fig["cited_in"]:
            path = ROOT / rel
            if not path.exists():
                failures.append(f"{name}: cited_in names a missing file, {rel}")
            elif not cited(path, claim):
                failures.append(
                    f"{name}: {rel} is listed as citing {claim:,} but does not contain it"
                )

        print(f"  ok  {name:<38} {claim:>9,}  in {len(fig['cited_in'])} file(s)")

    con.close()

    if failures:
        print(f"\n{len(failures)} figure check(s) FAILED:\n")
        for f in failures:
            print(f"  - {f}")
        print("\nEither the documentation is stale or the model changed. Fix one.")
        return 1

    print(f"\nAll {len(spec['figures'])} documented figures match the warehouse.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
