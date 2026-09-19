"""
load_raw.py — land the raw source files into the DuckDB warehouse (BRONZE).

This is deliberately the dumbest file in the project. It copies files into
`raw.*` tables and does nothing else:

    no renaming, no casting, no filtering, no joining, no business logic.

Every CSV is loaded with all_varchar=true, so *every column arrives as text*.
That looks wrong the first time you see it, and it is the point: types are
decided in exactly one place, the dbt staging layer. If the loader guessed
types as well, there would be two sources of truth that could disagree —
and DuckDB's guess would win silently.

The two API files are landed as raw JSON *text*, one row each. dbt parses
them later with SQL, so bronze never interprets them.

Idempotent: CREATE OR REPLACE means you can re-run this as often as you like
and get the same result.

Usage:
    python dw/src/load/load_raw.py
"""

from pathlib import Path

import duckdb

DW_ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = DW_ROOT / "raw"
DB_PATH = DW_ROOT / "warehouse" / "oj_dw.duckdb"

# raw table name -> source file. The prefix keeps the source system visible:
#   crm_  = the recruitment CRM export (OpenCATS-shaped)
#   fin_  = the finance system export
#   sec_  = the access list maintained by the BI team
#   ref_  = reference lists the business maintains (e.g. offices)
#   api_  = downloaded public reference data
CSV_SOURCES = {
    "crm_user": "crm/user.csv",
    "crm_company": "crm/company.csv",
    "crm_joborder": "crm/joborder.csv",
    "crm_candidate": "crm/candidate.csv",
    "crm_candidate_duplicates": "crm/candidate_duplicates.csv",
    "crm_status": "crm/candidate_joborder_status.csv",
    "crm_status_history": "crm/candidate_joborder_status_history.csv",
    "crm_industry": "crm/industry.csv",
    "crm_discipline": "crm/discipline.csv",
    "fin_placements": "finance/placements.csv",
    "fin_transactions": "finance/transactions.csv",
    "fin_targets": "finance/targets.csv",
    "sec_user_team": "security/security_user_team.csv",
    "ref_office": "reference/office.csv",
    "ref_funnel_stage": "reference/funnel_stage.csv",
}

JSON_SOURCES = {
    "api_fx_rates": "api/fx_rates.json",
    "api_bank_holidays": "api/bank_holidays.json",
}


def _load_csv_as_text(con, table: str, path: Path) -> None:
    """Create raw.<table> from a CSV, every column as VARCHAR."""
    con.execute(
        f"""
        create or replace table raw.{table} as
        select * from read_csv('{path.as_posix()}', header = true, all_varchar = true)
        """
    )


def _load_json_as_text(con, table: str, path: Path) -> None:
    """Create raw.<table> holding the JSON file as one row of text."""
    con.execute(
        f"""
        create or replace table raw.{table} as
        select filename, content from read_text('{path.as_posix()}')
        """
    )


def load_raw(db_path: Path = DB_PATH, raw_dir: Path = RAW_DIR) -> None:
    db_path.parent.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect(str(db_path))
    try:
        con.execute("create schema if not exists raw")
        
        for table, relative in CSV_SOURCES.items():
            path = raw_dir / relative
            if not path.exists():
                print(f"  [skip] {relative} not found")
                continue
            _load_csv_as_text(con, table, path)
            rows = con.execute(f"select count(*) from raw.{table}").fetchone()[0]
            cols = len(con.execute(f"select * from raw.{table} limit 0").description)
            print(f"  [ok]   raw.{table:<26} <- {relative:<42} {rows:>7,} rows, {cols:>2} cols")

        for table, relative in JSON_SOURCES.items():
            path = raw_dir / relative
            if not path.exists():
                print(f"  [skip] {relative} not found")
                continue
            _load_json_as_text(con, table, path)
            chars = con.execute(f"select length(content) from raw.{table}").fetchone()[0]
            print(f"  [ok]   raw.{table:<26} <- {relative:<42} 1 row, {chars:,} chars of JSON")

        # Flush the write-ahead log into the main file so the next process
        # (dbt) opens a consistent database.
        con.execute("checkpoint")
    finally:
        con.close()

    size_mb = db_path.stat().st_size / 1024 / 1024
    print(f"\n  Bronze load complete: {db_path} ({size_mb:.1f} MB)")


if __name__ == "__main__":
    load_raw()


