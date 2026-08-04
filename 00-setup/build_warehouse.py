"""Build the RetailIQ analytics database from every source in data/.

Produces a single DuckDB file, data/retailiq.duckdb, containing all seven sources
in one connection. No server, no admin rights, no install beyond `pip install duckdb`.

    pip install -r 00-setup/requirements.txt
    python 00-setup/build_warehouse.py

Re-running is safe: the database is rebuilt from scratch each time, so the result
is a pure function of what is in data/.

Schemas produced
    pagila.*    DVD rental, 21 tables, parsed straight out of the pg_dump
    chinook.*   music store, 11 tables, read from the SQLite file
    raw.*       the CSV, Parquet and JSON sources, landed as-is

Everything in raw.* is deliberately left as text where the source was text.
Typing and cleaning it is the project's job, not the loader's.
"""

from __future__ import annotations

import argparse
import re
import sys
import time
from pathlib import Path

try:
    import duckdb
except ImportError:
    sys.exit("duckdb is not installed. Run: pip install -r 00-setup/requirements.txt")

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
DB_PATH = DATA / "retailiq.duckdb"


def log(msg: str) -> None:
    print(msg, flush=True)


# --------------------------------------------------------------------------
# Pagila
# --------------------------------------------------------------------------
COPY_RE = re.compile(r"COPY\s+(?:public\.)?(\w+)\s*\(([^)]*)\)\s+FROM\s+stdin;", re.I)


def load_pagila(con) -> dict[str, int]:
    """Parse the COPY blocks out of pagila-data.sql.

    The dump is PostgreSQL-specific - plpgsql functions, triggers, tsvector columns,
    declarative partitioning - and 426 of its 428 DDL statements fail outside
    PostgreSQL. The data, though, sits in plain tab-separated COPY blocks that can be
    read directly. That is what this does: skip the DDL entirely, take the data.

    Columns land as VARCHAR. Inferring and casting the real types is Q2's work.
    """
    src = DATA / "pagila" / "pagila-master" / "pagila-data.sql"
    if not src.exists():
        log(f"  skip pagila, not found: {src}")
        return {}

    con.execute("CREATE SCHEMA IF NOT EXISTS pagila")
    loaded: dict[str, int] = {}
    table: str | None = None
    cols: list[str] = []
    rows: list[list[str | None]] = []
    in_copy = False

    def flush() -> None:
        nonlocal table, cols, rows
        if table and rows:
            colspec = ", ".join(f'"{c}" VARCHAR' for c in cols)
            con.execute(f'CREATE OR REPLACE TABLE pagila."{table}" ({colspec})')
            con.executemany(
                f'INSERT INTO pagila."{table}" VALUES ({", ".join("?" * len(cols))})',
                rows,
            )
            loaded[table] = len(rows)
        table, cols, rows = None, [], []

    with src.open(encoding="utf-8") as fh:
        for line in fh:
            if not in_copy:
                m = COPY_RE.search(line)
                if m:
                    table = m.group(1)
                    cols = [c.strip().strip('"') for c in m.group(2).split(",")]
                    rows, in_copy = [], True
                continue
            if line.startswith("\\."):
                flush()
                in_copy = False
                continue
            vals = line.rstrip("\n").split("\t")
            if len(vals) == len(cols):
                rows.append([None if v == "\\N" else v for v in vals])
    flush()

    # payment is range-partitioned by month in the source, arriving as ~60 sibling
    # tables. Union them into one so the model matches the logical entity. The
    # partitions are left in place - comparing the two is worthwhile.
    parts = sorted(t for t in loaded if t.startswith("payment_p"))
    if parts:
        union = " UNION ALL ".join(f'SELECT * FROM pagila."{p}"' for p in parts)
        con.execute(f"CREATE OR REPLACE TABLE pagila.payment AS {union}")
        n = con.execute("SELECT COUNT(*) FROM pagila.payment").fetchone()[0]
        loaded["payment"] = n
        log(f"  unioned {len(parts)} monthly payment partitions into pagila.payment ({n:,} rows)")

    return loaded


# --------------------------------------------------------------------------
# Chinook
# --------------------------------------------------------------------------
def load_chinook(con) -> dict[str, int]:
    """Copy the SQLite database in, table by table.

    DuckDB can ATTACH SQLite directly, so this is a straight read. Tables are
    materialised rather than left attached so the whole project lives in one file.
    """
    src = DATA / "chinook" / "Chinook_Sqlite.sqlite"
    if not src.exists():
        log(f"  skip chinook, not found: {src}")
        return {}

    con.execute("INSTALL sqlite; LOAD sqlite;")
    con.execute("CREATE SCHEMA IF NOT EXISTS chinook")
    con.execute(f"ATTACH '{src.as_posix()}' AS ch (TYPE sqlite, READ_ONLY)")

    loaded: dict[str, int] = {}
    tables = [
        r[0]
        for r in con.execute(
            "SELECT table_name FROM information_schema.tables WHERE table_catalog = 'ch'"
        ).fetchall()
    ]
    for t in tables:
        con.execute(f'CREATE OR REPLACE TABLE chinook."{t}" AS SELECT * FROM ch."{t}"')
        loaded[t] = con.execute(f'SELECT COUNT(*) FROM chinook."{t}"').fetchone()[0]
    con.execute("DETACH ch")
    return loaded


# --------------------------------------------------------------------------
# Flat files
# --------------------------------------------------------------------------
def load_raw_files(con, skip_taxi: bool = False) -> dict[str, int]:
    """Land the CSV, Parquet and JSON sources.

    all_varchar=true on the CSVs is deliberate. These files are the messy ones and
    the project's whole point is to profile and cast them by hand; letting the
    reader guess types would quietly do that work and hide the defects.
    """
    con.execute("CREATE SCHEMA IF NOT EXISTS raw")
    loaded: dict[str, int] = {}

    csvs = {
        "online_retail": DATA / "online-retail" / "online-retail.csv",
        "superstore_orders": DATA / "superstore" / "superstore-orders.csv",
        "superstore_returns": DATA / "superstore" / "superstore-returns.csv",
        "superstore_people": DATA / "superstore" / "superstore-people.csv",
        "hr_employees": DATA / "hr" / "HRDataset_v14.csv",
        "customers": DATA / "csv-samples" / "files" / "customers-100000.csv",
        "people": DATA / "csv-samples" / "files" / "people-100000.csv",
        "organizations": DATA / "csv-samples" / "files" / "organizations-100000.csv",
        "leads": DATA / "csv-samples" / "files" / "leads-10000.csv",
    }
    for name, path in csvs.items():
        if not path.exists():
            log(f"  skip {name}, not found")
            continue
        con.execute(
            f"CREATE OR REPLACE TABLE raw.{name} AS "
            f"SELECT * FROM read_csv_auto('{path.as_posix()}', all_varchar=true)"
        )
        loaded[f"raw.{name}"] = con.execute(f"SELECT COUNT(*) FROM raw.{name}").fetchone()[0]

    # Parquet keeps its types - it is a typed format, so there is nothing to infer.
    taxi = DATA / "nyc-taxi" / "yellow_tripdata_2024-01.parquet"
    if skip_taxi:
        log("  skip taxi_trips (--skip-taxi)")
    elif taxi.exists():
        con.execute(
            f"CREATE OR REPLACE TABLE raw.taxi_trips AS "
            f"SELECT * FROM read_parquet('{taxi.as_posix()}')"
        )
        loaded["raw.taxi_trips"] = con.execute("SELECT COUNT(*) FROM raw.taxi_trips").fetchone()[0]

    # GH Archive: keep the whole event as JSON alongside the flattened columns, so
    # the semi-structured work in Q19 has something real to dig into.
    gh = DATA / "gharchive" / "2024-01-01-15.json.gz"
    if gh.exists():
        con.execute("INSTALL json; LOAD json;")
        con.execute(
            f"CREATE OR REPLACE TABLE raw.gh_events AS SELECT "
            f"  id, type, public, created_at, "
            f"  actor.login AS actor_login, repo.name AS repo_name, "
            f"  to_json(payload) AS payload_json "
            f"FROM read_json_auto('{gh.as_posix()}')"
        )
        loaded["raw.gh_events"] = con.execute("SELECT COUNT(*) FROM raw.gh_events").fetchone()[0]

    return loaded


# --------------------------------------------------------------------------
def inventory(con) -> None:
    """Summarise what was built, counting rows for real rather than estimating."""
    tables = con.execute(
        """
        SELECT schema_name, table_name
        FROM duckdb_tables()
        ORDER BY schema_name, table_name
        """
    ).fetchall()

    rows_by_schema: dict[str, int] = {}
    tabs_by_schema: dict[str, int] = {}
    for schema, table in tables:
        n = con.execute(f'SELECT COUNT(*) FROM "{schema}"."{table}"').fetchone()[0]
        rows_by_schema[schema] = rows_by_schema.get(schema, 0) + n
        tabs_by_schema[schema] = tabs_by_schema.get(schema, 0) + 1

    log("")
    log("  schema      tables         rows")
    log("  " + "-" * 34)
    for schema in sorted(rows_by_schema):
        log(f"  {schema:<10} {tabs_by_schema[schema]:>6} {rows_by_schema[schema]:>12,}")
    log("  " + "-" * 34)
    log(f"  {'TOTAL':<10} {len(tables):>6} {sum(rows_by_schema.values()):>12,}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Build the RetailIQ DuckDB database.")
    ap.add_argument("--out", type=Path, default=DB_PATH, help="output .duckdb path")
    ap.add_argument("--skip-taxi", action="store_true", help="skip the 2.9M-row taxi table")
    args = ap.parse_args()

    if not DATA.exists():
        sys.exit(f"data/ not found at {DATA}. Clone the repo properly, or run 00-setup/fetch-data.ps1.")

    # Rebuild from scratch so the output is reproducible.
    if args.out.exists():
        args.out.unlink()
        log(f"removed existing {args.out.name}")

    t0 = time.time()
    con = duckdb.connect(str(args.out))

    log("loading pagila")
    p = load_pagila(con)
    log(f"  {len(p)} tables")

    log("loading chinook")
    c = load_chinook(con)
    log(f"  {len(c)} tables")

    log("loading raw files")
    r = load_raw_files(con, skip_taxi=args.skip_taxi)
    log(f"  {len(r)} tables")

    inventory(con)
    con.close()

    size_mb = args.out.stat().st_size / 1024 / 1024
    log("")
    log(f"built {args.out}  ({size_mb:,.0f} MB) in {time.time() - t0:,.0f}s")
    log("")
    log("Query it with:")
    log("  python -c \"import duckdb;print(duckdb.connect('data/retailiq.duckdb')"
        ".sql('SELECT * FROM chinook.Track LIMIT 5'))\"")
    log("or open data/retailiq.duckdb in DBeaver / DataGrip with the DuckDB driver.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
