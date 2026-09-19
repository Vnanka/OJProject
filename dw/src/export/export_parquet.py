"""
export_parquet.py — write the gold tables out as Parquet files for Power BI.

This is the last step of the pipeline:

    load_raw.py  ->  dbt build  ->  export_parquet.py  ->  Power BI

Why Parquet and not a live connection to DuckDB? Because a file cannot fail on
the day. Power BI imports the files; no driver, no service, no network.

Why Parquet and not CSV? Parquet stores the TYPE of every column, so Power BI
does not have to guess whether DateKey is a number or text, and money keeps its
decimal type. It is also compressed and imports much faster.

Only GOLD is exported. Bronze and silver stay inside the warehouse: they are
working layers, not something a report should read.

Idempotent: the files are overwritten, so run it as often as you like. Run it
only after a clean `dbt build` - if a test failed, the report should not get the
data.

Usage (from the project root, with the venv active):
    python dw/src/export/export_parquet.py
"""

from pathlib import Path

import duckdb

DW_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = DW_ROOT / "warehouse" / "oj_dw.duckdb"
EXPORT_DIR = DW_ROOT / "export" / "parquet"

# The gold layer, exactly as Power BI will see it: 8 dimensions, 5 facts and the
# security list. dim_FxRateMonthly is deliberately NOT exported - the conversion
# to GBP already happened in dbt, so the report never needs the rates.
GOLD_TABLES = [
    "dim_Date",
    "dim_Office",
    "dim_Industry",
    "dim_Discipline",
    "dim_Consultant",
    "dim_Client",
    "dim_Vacancy",
    "dim_Stage",
    "fact_Application",
    "fact_ApplicationLine",
    "fact_Placement",
    "fact_FeeTransaction",
    "fact_Target",
    "sec_UserTeam",
]


def export_parquet(db_path: Path = DB_PATH, export_dir: Path = EXPORT_DIR) -> None:
    export_dir.mkdir(parents=True, exist_ok=True)

    # read_only: the export can never change the warehouse by accident.
    con = duckdb.connect(str(db_path), read_only=True)
    try:
        total_rows = 0
        total_bytes = 0

        for table in GOLD_TABLES:
            out = export_dir / f"{table}.parquet"
            con.execute(
                f"""
                copy (select * from main.{table})
                to '{out.as_posix()}' (format parquet, compression zstd)
                """
            )

            # Read the row count back OUT of the file, not out of the table:
            # that proves the file Power BI will read is the one we meant.
            rows = con.execute(
                f"select count(*) from read_parquet('{out.as_posix()}')"
            ).fetchone()[0]
            size_kb = out.stat().st_size / 1024

            total_rows += rows
            total_bytes += out.stat().st_size
            print(f"  [ok]   {table:<22} {rows:>9,} rows  {size_kb:>8,.0f} KB")

    finally:
        con.close()

    print(
        f"\n  Exported {len(GOLD_TABLES)} gold tables to {export_dir}"
        f"\n  {total_rows:,} rows, {total_bytes / 1024 / 1024:.1f} MB total"
    )


if __name__ == "__main__":
    export_parquet()
