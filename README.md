# RetailIQ Analytics Platform

SQL mastery capstone. The premise: I am the analytics engineer at **RetailIQ**, a retailer selling music (Chinook catalogue) and DVDs (Pagila catalogue). The work is to ingest messy e-commerce CSVs, clean them, build a warehouse, and deliver analytics on top of it.

## Repository layout

| Path | Purpose |
| --- | --- |
| `00-setup` | Environment setup, database bootstrap, connection notes |
| `01-foundations` | SQL foundations |
| `02-single-table` | Single-table querying |
| `03-module` … `36-module` | One folder per module, renamed as each module is worked through |
| `data` | Local datasets (git-ignored, see download links below) |
| `ddl` | Schema definitions: staging, dimensions, facts, marts |
| `queries` | Analytical queries and reporting SQL |
| `tests` | Data quality and assertion checks |
| `docs` | Data dictionary, ERDs, decisions, module write-ups |

## Data

Datasets are **not** committed. GitHub rejects any single file over 100MB and repositories hold code, not data. Download into `data/` after cloning.

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

Write the `.sql` file for a module, then commit and push at the end of that module rather than batching everything to the end.
