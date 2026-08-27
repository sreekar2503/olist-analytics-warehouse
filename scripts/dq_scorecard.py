"""
Build a data quality scorecard from dbt's own artifacts.

`manifest.json` holds each test's `meta.dq_dimension`; `run_results.json` holds
its pass/fail and failing-row count. Neither alone is a scorecard. This joins
them, so the numbers published in the README are produced by the run rather
than typed by hand.

Two rules this script follows deliberately:

* **An untagged test is reported, not hidden.** It lands in an `untagged` row.
* **A dimension with no tests is reported, not dropped.** It keeps its row with
  a zero count. A quality dimension you have no coverage for is a finding worth
  publishing, and reindexing it away is exactly the kind of quiet omission this
  project exists to argue against.

Output is sorted and carries no timestamps, so re-running an unchanged build
produces a byte-identical CSV -- which is what makes the CI diff-check
meaningful.
"""

import json
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "dbt" / "target"
OUT = ROOT / "docs" / "dq_scorecard.csv"

# The six DAMA / standard data quality dimensions, in a fixed published order.
DIMENSIONS = [
    "completeness",
    "validity",
    "accuracy",
    "consistency",
    "timeliness",
    "uniqueness",
]


def dq_dimension(node: dict) -> str:
    """Read the tag a test was annotated with, from either place dbt stores it."""
    config_meta = (node.get("config") or {}).get("meta") or {}
    node_meta = node.get("meta") or {}
    return config_meta.get("dq_dimension") or node_meta.get("dq_dimension") or "untagged"


def collect(manifest: dict, results: dict) -> pd.DataFrame:
    rows = []
    for r in results["results"]:
        node = manifest["nodes"].get(r["unique_id"], {})
        if node.get("resource_type") != "test":
            continue
        rows.append(
            {
                "test": node["name"],
                "dimension": dq_dimension(node),
                "passed": r["status"] == "pass",
                "failures": int(r.get("failures") or 0),
            }
        )
    return pd.DataFrame(rows, columns=["test", "dimension", "passed", "failures"])


def scorecard(df: pd.DataFrame) -> pd.DataFrame:
    # Every standard dimension gets a row even with zero tests; anything tagged
    # with something off-list, or untagged, is appended so it cannot go unseen.
    extra = sorted(set(df["dimension"]) - set(DIMENSIONS))
    index = DIMENSIONS + extra

    grouped = (
        df.groupby("dimension")
        .agg(tests=("test", "size"), passed=("passed", "sum"), failing_rows=("failures", "sum"))
        .reindex(index)
        .fillna(0)
        .astype(int)
    )
    grouped["pass_rate"] = [
        round(p / t, 3) if t else None for p, t in zip(grouped["passed"], grouped["tests"])
    ]
    grouped.index.name = "dimension"
    return grouped


def main() -> int:
    for artifact in ("manifest.json", "run_results.json"):
        if not (TARGET / artifact).exists():
            print(f"ERROR: {TARGET / artifact} not found. Run `dbt build` first.")
            return 1

    manifest = json.loads((TARGET / "manifest.json").read_text())
    results = json.loads((TARGET / "run_results.json").read_text())

    df = collect(manifest, results)
    if df.empty:
        print("ERROR: run_results.json contains no test results. Did `dbt build` run tests?")
        return 1

    card = scorecard(df)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    card.to_csv(OUT)
    print(card.to_string())

    uncovered = [d for d in DIMENSIONS if card.loc[d, "tests"] == 0]
    if uncovered:
        print(f"\nUNCOVERED dimensions (a finding, not a crash): {', '.join(uncovered)}")
    if "untagged" in card.index:
        print(f"UNTAGGED tests: {card.loc['untagged', 'tests']} -- tag them or explain why not.")
    print(f"\nWrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
