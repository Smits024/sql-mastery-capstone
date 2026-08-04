# RetailIQ Analytics Platform

SQL mastery capstone. The premise: I am the analytics engineer at **RetailIQ**, a retailer selling music (Chinook catalogue) and DVDs (Pagila catalogue). The work is to ingest messy e-commerce CSVs, clean them, build a warehouse, and deliver analytics on top of it.

## Repository layout

| Path | Purpose |
| --- | --- |
| `00-setup` | Environment setup, database bootstrap, connection and load notes |
| `01-foundations` | SQL foundations: syntax, data types, casting, NULL semantics |
| `02-single-table` | Single-table work: filtering, sorting, pagination, CASE, string functions |
| `03-joins` | Inner, outer, self, multi, cross and non-equi joins; fan-out traps |
| `04-aggregation` | Aggregate functions, GROUP BY, HAVING, ROLLUP, DISTINCT |
| `05-subqueries-ctes` | Scalar and correlated subqueries, EXISTS, CTEs, recursion |
| `06-windows` | Ranking, LAG/LEAD, running totals, top-N, dedup, gaps and islands, pivots |
| `07-set-ops` | UNION, INTERSECT, EXCEPT and their ALL variants |
| `08-dml` | INSERT/UPDATE/DELETE, MERGE and upserts, transactions, TRUNCATE vs DELETE |
| `09-etl` | CSV loading, string and key-value parsing, dedup, date cleaning |
| `10-warehouse` | Star schema design, fact and dimension loads, SCD type 1 and type 2 |
| `36-capstone-report` | Final capstone deliverable and write-up |
| `ddl` | Schema definitions: staging, dimensions, facts, marts |
| `queries` | Analytical queries and reporting SQL |
| `tests` | Data quality and assertion checks |
| `data` | Local datasets (git-ignored, see download links below) |
| `docs` | Data dictionary, ERDs, decisions, module write-ups |

## Data

Datasets are **not** committed. GitHub rejects any single file over 100MB and repositories hold code, not data. After cloning, fetch every no-login dataset in one shot:

```powershell
pwsh -File 00-setup/fetch-data.ps1
```

That lands ~240 MB in `data/` and skips anything already downloaded. See `data/README.md` for the resulting layout, row counts, and load instructions. The Kaggle datasets below need an account and must be fetched manually. Source URLs are listed here for reference.

### No login required

- **Chinook (Dataset A)** — single SQLite file, ready to open:
  `https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite`
- **Pagila (Dataset B)** — repo zip; run `pagila-schema.sql` first, then `pagila-data.sql`:
  `https://github.com/devrimgunduz/pagila/archive/refs/heads/master.zip`
- **Employees CSV (Dataset C)** — zip of sample CSVs:
  `https://github.com/datablist/sample-csv-files/archive/refs/heads/main.zip`
- **NYC Taxi (Dataset C)** — one month of yellow-cab trips, Parquet, ~50MB. Swap `2024-01` for another month:
  `https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet`
- **GH Archive (Dataset D)** — real GitHub events as JSON lines:
  `https://data.gharchive.org/2024-01-01-15.json.gz`

### Kaggle account required

- Superstore Sales: `https://www.kaggle.com/datasets/vivek468/superstore-dataset-final`
- E-commerce: `https://www.kaggle.com/datasets/carrie1/ecommerce-data`
- HR / org hierarchy: `https://www.kaggle.com/datasets/neurocipher/employee-dataset`

Start with the Chinook `.sqlite` file — one download, no setup, and it covers joins, aggregates, and window functions.

## Workflow

Write the `.sql` files for a section, then commit and push at the end of that section rather than batching everything to the end.
