# Olist Analytics Warehouse

<!-- TODO(sreekar): write the opening in your own words. Lead with the finding,
     not the stack. Dashboard screenshot first, lineage DAG second, prose third.
     Target under 600 words total. -->

## Data licence

The Olist Brazilian E-Commerce dataset is **CC BY-NC-SA 4.0** and is **not
redistributed** from this repository. `data/` is gitignored. See
[LICENSE-DATA.md](LICENSE-DATA.md) for the full terms and what they mean here.

Code in this repository is MIT — see [LICENSE](LICENSE).

## Reproducing this

You need a Kaggle account. Nothing else is downloaded for you.

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt kaggle
```

Set up a Kaggle API token (Kaggle → Settings → API → Create New Token) and save
it to `~/.kaggle/access_token` as Kaggle instructs. Then:

```bash
kaggle datasets download -d olistbr/brazilian-ecommerce -p data/raw --unzip
python scripts/load_raw.py
cd dbt && dbt deps --profiles-dir . && dbt build --profiles-dir . && cd ..
python scripts/profile_raw.py
python scripts/dq_scorecard.py
python scripts/export_lineage.py
```

Every generated artifact in `docs/` should then be unchanged:

```bash
git diff --exit-code -- docs/dq_scorecard.csv docs/lineage.json docs/profile_raw.md
```

That command is also a CI step. It uses `--exit-code`, not `--stat`, because
`git diff --stat` prints the difference and exits 0 either way — a check written
that way can never fail.

## Generated artifacts

Nothing in this list is written by hand. Each is produced by the build and
checked by CI.

| Artifact | Produced by |
|---|---|
| [`docs/profile_raw.md`](docs/profile_raw.md) | `scripts/profile_raw.py` |
| [`docs/dq_scorecard.csv`](docs/dq_scorecard.csv) | `scripts/dq_scorecard.py` |
| [`docs/lineage.json`](docs/lineage.json) | `scripts/export_lineage.py` |

<!-- TODO(sreekar): sections still to write —
     - The finding (lead with it)
     - The four business questions and the dashboard
     - Star schema diagram and declared grains
     - DQ scorecard, read out in prose, including the uncovered dimensions
     - What this warehouse quietly excludes -->
