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

Datasets are committed to this repo, so `git clone` gives you the code and the data together with nothing else to run. The clone is roughly **270 MB** — expect it to take a minute.

That includes Superstore and Online Retail, taken from their primary sources (Tableau public sample data and the UCI ML Repository) rather than the Kaggle re-uploads, so no account is needed. `00-setup/fetch-data.ps1` re-downloads everything from source, and `00-setup/excel-to-csv.py` regenerates the CSVs from the Excel originals. See `data/README.md` for layout, row counts, and load instructions.

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

### Sourced upstream of Kaggle, no account needed

- **Online Retail** — UCI ML Repository dataset 352, the original of Kaggle's `carrie1/ecommerce-data`:
  `https://archive.ics.uci.edu/static/public/352/online+retail.zip`
- **Superstore** — Tableau public sample data, the original of Kaggle's `vivek468/superstore-dataset-final`:
  `https://public.tableau.com/app/sample-data/sample_-_superstore.xls`
- **HR** — Rich Huebner's Human Resources Data Set (Kaggle `rhuebner/human-resources-data-set`), via public mirror:
  `https://raw.githubusercontent.com/pouyasattari/HR-Dataset-Analysis/main/HRDataset_v14.csv`

The `neurocipher/employee-dataset` link in the original project notes is dead (404); the HR dataset above is what it referred to. For recursive hierarchy work use Chinook's `Employee.ReportsTo`, not the HR table's `ManagerID` — see `data/README.md` for why.

Start with the Chinook `.sqlite` file — one download, no setup, and it covers joins, aggregates, and window functions.

## Workflow

Write the `.sql` files for a section, then commit and push at the end of that section rather than batching everything to the end.
