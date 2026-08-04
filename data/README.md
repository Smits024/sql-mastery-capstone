# Data

These datasets are committed to the repo — a clone gives you everything below, no download step. Only the downloaded `.zip` archives are ignored, since their extracted contents are tracked instead.

## Layout

```
data/
  chinook/      Chinook_Sqlite.sqlite                 0.96 MB   ready to open
  pagila/       pagila-master/                        43 MB     PostgreSQL dump
  csv-samples/  files/*.csv                           48 MB     7 files
  nyc-taxi/     yellow_tripdata_2024-01.parquet       47.7 MB
  gharchive/    2024-01-01-15.json.gz                 79.3 MB   180,387 JSON lines
  online-retail/ online-retail.csv                    46.3 MB   541,909 rows
  superstore/   superstore-{orders,returns,people}.csv 2.4 MB   3 related tables
  hr/           HRDataset_v14.csv                     0.07 MB   311 rows, 36 columns
```

Total tracked: ~270 MB. The GH Archive file is 79.3 MB, over GitHub's 50 MB recommendation but under the 100 MB hard limit, so it pushes with a warning and no LFS.

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

## The Kaggle datasets, taken from their primary sources

Two of the three Kaggle datasets are re-uploads of data that is published elsewhere with no
account required, so they are sourced directly and committed like everything else.

**Online Retail** — `online-retail/online-retail.csv`. 541,909 rows, 8 columns:
`InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country`.
This is the UCI Machine Learning Repository's Online Retail dataset (dataset 352), which is what
Kaggle's `carrie1/ecommerce-data` is a copy of — the row count matches exactly. UK online gift
retailer, Dec 2010 to Dec 2011. Genuinely messy: negative quantities for returns, null
`CustomerID` on guest checkouts, cancelled invoices prefixed `C`. Good for the cleaning modules.

The source `.xlsx` (22.6 MB) is git-ignored since the CSV supersedes it; re-create it with
`fetch-data.ps1` if needed.

**Superstore** — `superstore/`. Tableau's official public sample data, the origin of Kaggle's
`vivek468/superstore-dataset-final`. Three sheets, one CSV each:

| File | Rows | Contents |
| --- | --- | --- |
| `superstore-orders.csv` | 10,194 | 21 columns: order and ship dates, segment, geography, product hierarchy, sales, discount, profit |
| `superstore-returns.csv` | 296 | `Order ID`, `Returned` — joins back to orders |
| `superstore-people.csv` | 4 | `Regional Manager`, `Region` |

The original `sample-superstore.xls` is kept alongside. Three related tables make this the best
dataset here for join and star-schema practice.

**HR** — `hr/HRDataset_v14.csv`. 311 rows, 36 columns. Rich Huebner's Human Resources Data Set,
pulled from a public GitHub mirror so no Kaggle account is needed. The Kaggle page is
`rhuebner/human-resources-data-set`.

Note: the dataset named in the original project notes, `neurocipher/employee-dataset`, does not
exist — that URL returns 404. This is the dataset it was pointing at.

Columns worth knowing: `EmpID`, `Employee_Name`, `Department`, `Position`, `Salary`,
`DateofHire`, `DateofTermination`, `TermReason`, `EmploymentStatus`, `PerformanceScore`,
`EngagementSurvey`, `Absences`, `ManagerName`, `ManagerID`. The BOM on the original header was
stripped, so `Employee_Name` parses cleanly as the first column.

**This table is not a recursive hierarchy.** `ManagerID` runs 1–39 while `EmpID` runs
10001–10311, and **zero** `ManagerID` values match any `EmpID`. No manager appears as an employee
row. It is a flat two-level lookup into a manager list that is not in the data, so it will not
drive a recursive CTE. Two real quirks that make it good cleaning material: 23 distinct
`ManagerID` values map to only 21 distinct `ManagerName` values, and 8 rows have a blank
`ManagerID`.

For genuine recursion use Chinook's `Employee` table instead — 8 rows, `ReportsTo` is a true
self-referencing FK (7 of 8 rows resolve to a real `EmployeeId`, 1 root with `ReportsTo IS NULL`),
and a recursive CTE walks it to depth 3. Verified working.

## Regenerating the CSVs

Both Excel sources are flattened by `00-setup/excel-to-csv.py` (needs `pandas`, `openpyxl`, `xlrd`).

## Re-download

See `00-setup/` for the fetch script, or the source URLs in the root `README.md`.
