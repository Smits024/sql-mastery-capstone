# Setup

Three commands and you have every dataset queryable from one connection.

```powershell
pip install -r 00-setup/requirements.txt
python 00-setup/build_warehouse.py
```

That writes `data/retailiq.duckdb` — 93 tables, 4.2 million rows, about 721 MB, in roughly
100 seconds. The database is git-ignored: it is derived from `data/`, so rebuild it rather than
sync it.

## Why DuckDB

The obvious choice for a warehouse project is PostgreSQL, and for a project this shape it is the
better engine on paper. It was rejected for a concrete reason: **it cannot be installed here.**
No Docker daemon, no `psql`, no server, and the second laptop this project has to run on is locked
down further. A setup step that begins "install PostgreSQL 16" is a setup step that never happens.

DuckDB is a single `pip install` of a pure wheel. No server, no daemon, no admin rights, no
connection string. And it reads every format in `data/` natively — Parquet, gzipped JSON-lines,
CSV, and SQLite — which removes the conversion work entirely.

It is also not a toy. Verified against this repo's data, DuckDB 1.5 supports:

| | |
| --- | --- |
| Windows | `ROWS` / `RANGE` / `GROUPS` frames, `EXCLUDE`, named `WINDOW`, `QUALIFY` |
| Grouping | `GROUPING SETS`, `ROLLUP`, `CUBE`, `GROUPING()`, `FILTER` |
| Stats | `PERCENTILE_CONT/DISC`, `MODE() WITHIN GROUP`, `CORR`, `REGR_*` |
| Queries | recursive CTEs, `LATERAL`, `DISTINCT ON`, `INTERSECT`/`EXCEPT ALL`, `PIVOT`/`UNPIVOT` |
| Writes | `MERGE INTO`, `INSERT ... ON CONFLICT`, transactions with `ROLLBACK`, enforced `CHECK` |
| Types | `STRUCT`, `LIST`, JSON, `TRY_CAST`, `TABLESAMPLE`, `generate_series` |

## What DuckDB will not do

Four topics in the project need PostgreSQL. They are called out where they appear so nothing is
silently skipped:

| Topic | Question | Why |
| --- | --- | --- |
| Isolation levels, `SKIP LOCKED`, deadlocks | Q17 | DuckDB is single-writer, so multi-session concurrency cannot be demonstrated |
| Materialized views, GIN indexes, `EXPLAIN (BUFFERS)` | Q18 | Not implemented, or shaped differently |
| `FETCH FIRST ... WITH TIES` | Q6 | Not supported — use `QUALIFY RANK() OVER (...) = 1` |
| Native Pagila DDL | — | See below |

For those, run PostgreSQL when you have a machine that permits it. The rest of the project — 16 of
20 questions in full — runs on DuckDB unchanged.

## How Pagila is loaded

`pagila-schema.sql` is a PostgreSQL dump and **426 of its 428 statements fail** outside
PostgreSQL: 9 plpgsql functions, 16 triggers, 2 `tsvector` columns, 13 sequences, 2 domains, and
declarative partitioning. Translating that DDL faithfully is not worth it.

The data, though, sits in plain tab-separated `COPY ... FROM stdin` blocks. `build_warehouse.py`
skips the DDL entirely and parses those blocks directly — 70 tables, no PostgreSQL involved.

Two consequences worth knowing:

- **Columns land as `VARCHAR`.** Type inference and casting is Q2's job, so the loader
  deliberately does not do it. The same applies to the CSVs, loaded with `all_varchar=true`.
- **`payment` arrives as 55 monthly partitions** (`payment_p2022_01` …). The loader unions them
  into `pagila.payment` (51,061 rows) and leaves the partitions in place. Comparing a query against
  the union with the same query against one partition is a free lesson in partition pruning.

## Layout

| Schema | Tables | Rows | Contents |
| --- | --- | --- | --- |
| `chinook` | 11 | 15,607 | Music store, from the SQLite file |
| `pagila` | 71 | 173,270 | DVD rental, parsed from the pg_dump |
| `raw` | 11 | 4,007,725 | CSV, Parquet and JSON sources, landed as-is |

`raw` includes `taxi_trips` (2,964,624 rows from Parquet) and `gh_events` (180,387 rows from
gzipped JSON, with the full payload kept as JSON for the semi-structured work in Q19).

Pass `--skip-taxi` to build without the 2.9M-row table if you want a faster, smaller database.

## Querying it

Any tool with a DuckDB driver — DBeaver, DataGrip, the VS Code extension — can open
`data/retailiq.duckdb` directly. Or from Python:

```python
import duckdb
con = duckdb.connect("data/retailiq.duckdb", read_only=True)
con.sql("SELECT * FROM chinook.Track LIMIT 5").show()
```

Use `read_only=True` when you only intend to read; DuckDB allows a single writer, and a stray
write connection will lock out the others.

## Other scripts here

| Script | Purpose |
| --- | --- |
| `bootstrap.ps1` | Clone the repo on a new machine and verify the datasets arrived intact |
| `fetch-data.ps1` | Re-download every dataset from source (the data is committed, so this is only for refreshing) |
| `excel-to-csv.py` | Regenerate the Online Retail and Superstore CSVs from their Excel originals |
| `build_warehouse.py` | Build `data/retailiq.duckdb` from everything in `data/` |
