"""
Export a deterministic lineage artifact from dbt's manifest.

Why this exists rather than diffing `manifest.json` directly:

    manifest.json embeds `metadata.generated_at` and `metadata.invocation_id`.
    Two identical builds produce two different files. A CI step that diffs it
    can only ever be red, which means it would be deleted within a week and the
    lineage claim would go back to being unverified.

So this extracts the part that *should* be stable -- every node, its type,
materialisation, declared grain, and what it depends on -- sorts it, and drops
everything time-varying. `docs/lineage.json` is then committed, and CI fails if
a build changes the shape of the DAG without someone committing the new shape.

That is the check the README's lineage claim actually rests on.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "dbt" / "target" / "manifest.json"
OUT = ROOT / "docs" / "lineage.json"


def main() -> int:
    if not MANIFEST.exists():
        print(f"ERROR: {MANIFEST} not found. Run `dbt build` (or `dbt parse`) first.")
        return 1

    manifest = json.loads(MANIFEST.read_text())

    models = []
    for node in manifest["nodes"].values():
        if node["resource_type"] != "model":
            continue
        models.append(
            {
                "name": node["name"],
                "path": node["original_file_path"],
                "materialized": node["config"]["materialized"],
                "schema": node["schema"],
                "description": (node.get("description") or "").strip(),
                "columns": sorted(node.get("columns", {})),
                "depends_on": sorted(
                    manifest["nodes"][u]["name"]
                    for u in node["depends_on"]["nodes"]
                    if u in manifest["nodes"]
                ),
                "sources": sorted(
                    ".".join(manifest["sources"][u]["identifier"].split("."))
                    for u in node["depends_on"]["nodes"]
                    if u in manifest["sources"]
                ),
            }
        )

    tests = []
    for node in manifest["nodes"].values():
        if node["resource_type"] != "test":
            continue
        meta = (node.get("config") or {}).get("meta") or {}
        tests.append(
            {
                "name": node["name"],
                "dq_dimension": meta.get("dq_dimension", "untagged"),
                "severity": (node.get("config") or {}).get("severity", "error"),
                "tests_models": sorted(
                    manifest["nodes"][u]["name"]
                    for u in node["depends_on"]["nodes"]
                    if u in manifest["nodes"]
                ),
            }
        )

    payload = {
        "models": sorted(models, key=lambda m: m["name"]),
        "tests": sorted(tests, key=lambda t: (t["name"], t["dq_dimension"])),
        "counts": {"models": len(models), "tests": len(tests)},
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(f"Wrote {OUT.relative_to(ROOT)}: {len(models)} models, {len(tests)} tests")
    return 0


if __name__ == "__main__":
    sys.exit(main())
