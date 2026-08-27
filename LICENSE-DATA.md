# Data Licence

## Source

**Brazilian E-Commerce Public Dataset by Olist**
Published on Kaggle: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

## Licence

The dataset is published under **CC BY-NC-SA 4.0**
(Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International).
Full terms: https://creativecommons.org/licenses/by-nc-sa/4.0/

## What that permits, and what it requires

| Term | Meaning for this repo |
|---|---|
| **BY** — Attribution | Olist is credited above and in the README. |
| **NC** — NonCommercial | This repository is a personal portfolio project. It is not used commercially and must not be. |
| **SA** — ShareAlike | Derivative data (the DuckDB warehouse, the marts) inherits CC BY-NC-SA 4.0. |

## Consequences for this repository

1. **The raw CSVs are not committed.** `data/` is gitignored. Anyone reproducing
   this project downloads the dataset from Kaggle themselves — see the README.
2. **The built warehouse is not committed.** `data/olist.duckdb` is a derivative
   work of NC-licensed data and stays local.
3. **Aggregate figures published in this repo** (the DQ scorecard, metric values
   quoted in the README, the Tableau dashboard) are derivative works and are
   published under the same CC BY-NC-SA 4.0 licence, with attribution to Olist.
4. **The code in this repository** — SQL models, Python scripts, tests, CI — is
   the author's own work and carries the licence in `LICENSE` (MIT). The data
   licence and the code licence are separate.

## Note on the code licence

MIT on the code does not launder the data licence. Anyone using this code against
the Olist dataset remains bound by CC BY-NC-SA 4.0 for the data and anything
derived from it.
