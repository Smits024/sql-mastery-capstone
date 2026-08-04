# Data

Everything in this folder except this file and `.gitkeep` is git-ignored. Nothing here is committed — the layout below is what a fresh clone should recreate locally.

## Layout

```
data/
  chinook/      Chinook_Sqlite.sqlite                 0.96 MB   ready to open
  pagila/       pagila-master.zip + pagila-master/    20.8 MB   PostgreSQL dump
  csv-samples/  files/*.csv                           48 MB     7 files
  nyc-taxi/     yellow_tripdata_2024-01.parquet       47.7 MB
  gharchive/    2024-01-01-15.json.gz                 79.3 MB   180,387 JSON lines
```

## What is here

**Chinook (Dataset A)** — `chinook/Chinook_Sqlite.sqlite`. Single SQLite file, no setup. Open directly with any SQLite client. Verified: file header reads `SQLite format 3`.

**Pagila (Dataset B)** — `pagila/pagila-master/`. PostgreSQL sample DVD-rental database. Load order matters:

```bash
psql -d pagila -f pagila-schema.sql
psql -d pagila -f pagila-data.sql      # 12.5 MB, COPY-based
```

`pagila-insert-data.sql` (18.6 MB) is an alternative to `pagila-data.sql` using INSERT statements instead of COPY — use one or the other, not both. The `-jsonb`, `-pgq`, `-temporal` and `pg_partman` files are optional extras.

**Sample CSVs (Dataset C)** — `csv-samples/files/`:

| File | Rows | Size |
| --- | --- | --- |
| `customers-10000.csv` | 10,000 | 1.6 MB |
| `customers-100000.csv` | 100,000 | 16.5 MB |
| `people-10000.csv` | 10,000 | 1.1 MB |
| `people-100000.csv` | 100,000 | 11.1 MB |
| `organizations-10000.csv` | 10,000 | 1.3 MB |
| `organizations-100000.csv` | 100,000 | 13.4 MB |
| `leads-10000.csv` | 10,000 | 2.3 MB |

Note: the `datablist/sample-csv-files` repo zip contains only Python generator scripts, **not** the CSVs. The actual files are Google Drive links listed in that repo's README; the ones above were pulled from there. Larger variants (500k, 1M, 2M rows) exist at the same source if a bigger load test is wanted.

**NYC Taxi (Dataset C)** — `nyc-taxi/yellow_tripdata_2024-01.parquet`. Verified: `PAR1` magic bytes. Swap `2024-01` in the URL for other months.

**GH Archive (Dataset D)** — `gharchive/2024-01-01-15.json.gz`. 180,387 newline-delimited JSON event records, one hour of real GitHub activity. Good for the JSON-parsing and semi-structured modules.

## Not downloaded (Kaggle sign-in required)

These need an interactive Kaggle login, so fetch them manually into `data/kaggle/`:

- Superstore Sales: `https://www.kaggle.com/datasets/vivek468/superstore-dataset-final`
- E-commerce: `https://www.kaggle.com/datasets/carrie1/ecommerce-data`
- HR / org hierarchy: `https://www.kaggle.com/datasets/neurocipher/employee-dataset`

With the Kaggle CLI configured (`~/.kaggle/kaggle.json`) these become:

```bash
kaggle datasets download -d vivek468/superstore-dataset-final -p data/kaggle --unzip
kaggle datasets download -d carrie1/ecommerce-data          -p data/kaggle --unzip
kaggle datasets download -d neurocipher/employee-dataset    -p data/kaggle --unzip
```

## Re-download

See `00-setup/` for the fetch script, or the source URLs in the root `README.md`.
