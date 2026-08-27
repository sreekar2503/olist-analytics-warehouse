"""
Load the nine Olist CSVs into DuckDB's `raw` schema, verbatim.

Two deliberate choices:

1. **Every column is loaded as VARCHAR.** DuckDB's type sniffer is good, but a
   value it cannot parse becomes NULL at load time and nothing complains. Typing
   in staging instead means every cast is written down, reviewable, and testable,
   and a bad value shows up as a failed cast rather than a silent null.

2. **Column names are preserved exactly as shipped**, including the misspelling
   `product_name_lenght`. Corrections happen in staging, never here. A raw layer
   that quietly fixes the source is a raw layer you can no longer diff against
   the source.

Missing files are a hard error. A warehouse built on eight of nine tables should
not build at all.
"""

import sys
from pathlib import Path

import duckdb

RAW_DIR = Path(__file__).resolve().parents[1] / "data" / "raw"
DB_PATH = Path(__file__).resolve().parents[1] / "data" / "olist.duckdb"

# Kaggle filename -> raw table name used by models/staging/_sources.yml
TABLES = {
    "olist_orders_dataset.csv": "orders",
    "olist_order_items_dataset.csv": "order_items",
    "olist_customers_dataset.csv": "customers",
    "olist_products_dataset.csv": "products",
    "olist_sellers_dataset.csv": "sellers",
    "olist_order_reviews_dataset.csv": "order_reviews",
    "olist_order_payments_dataset.csv": "order_payments",
    "olist_geolocation_dataset.csv": "geolocation",
    "product_category_name_translation.csv": "product_category_name_translation",
}


def main() -> int:
    missing = [f for f in TABLES if not (RAW_DIR / f).exists()]
    if missing:
        print(f"ERROR: {len(missing)} of {len(TABLES)} CSVs missing from {RAW_DIR}:")
        for f in missing:
            print(f"  - {f}")
        print("\nDownload the dataset from Kaggle -- see README.md 'Reproducing this'.")
        return 1

    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB_PATH))
    con.execute("create schema if not exists raw")

    for filename, table in TABLES.items():
        path = (RAW_DIR / filename).as_posix()
        con.execute(f"drop table if exists raw.{table}")
        con.execute(
            f"""
            create table raw.{table} as
            select * from read_csv(
                '{path}',
                all_varchar = true,   -- see module docstring
                header = true
            )
            """
        )
        rows = con.execute(f"select count(*) from raw.{table}").fetchone()[0]
        cols = len(con.execute(f"select * from raw.{table} limit 0").description)
        print(f"  raw.{table:<34} {rows:>7,} rows  {cols:>2} cols")

    con.close()
    print(f"\nLoaded {len(TABLES)} tables into {DB_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
