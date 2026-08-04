# RetailIQ Analytics Platform

SQL mastery capstone. The premise: I am the analytics engineer at **RetailIQ**, a retailer selling music (Chinook catalogue) and DVDs (Pagila catalogue). The work is to ingest messy e-commerce CSVs, clean them, build a warehouse, and deliver analytics on top of it.

## Repository layout

| Path | Purpose |
| --- | --- |
| `module-01` … `module-36` | One folder per module, in course order (see below) |
| `data` | Local datasets (git-ignored, see download links below) |
| `ddl` | Schema definitions: staging, dimensions, facts, marts |
| `queries` | Analytical queries and reporting SQL |
| `tests` | Data quality and assertion checks |
| `docs` | Data dictionary, ERDs, decisions, module write-ups |

## Modules

**Foundations and single-table**

1. `module-01-setup-and-inventory`
2. `module-02-select-and-expressions`
3. `module-03-where-filtering`
4. `module-04-sorting-and-pagination`
5. `module-05-data-types-and-cast`
6. `module-06-null-handling`
7. `module-07-case-and-strings`

**Joins**

8. `module-08-inner-join`
9. `module-09-outer-joins`
10. `module-10-self-and-multi-joins`
11. `module-11-cross-join-and-fanout`
12. `module-12-non-equi-join`

**Aggregation**

13. `module-13-aggregate-functions`
14. `module-14-group-by-and-having`
15. `module-15-rollup-distinct`

**Subqueries and CTEs**

16. `module-16-subqueries`
17. `module-17-exists-and-not-exists`
18. `module-18-cte-and-recursive`

**Window functions**

19. `module-19-window-ranking`
20. `module-20-window-lag-lead-running`
21. `module-21-topn-dedup-gaps-islands`
22. `module-22-pivot-and-conditional-agg`
23. `module-23-set-operations`

**Writes and transactions**

24. `module-24-insert-update-delete`
25. `module-25-merge-upsert-transactions`
26. `module-26-truncate-vs-delete`

**Schema and performance**

27. `module-27-ddl-and-constraints`
28. `module-28-indexes-and-explain`
29. `module-29-views-and-materialized`

**Ingestion and cleaning**

30. `module-30-load-csv-and-parse-strings`
31. `module-31-parse-key-value-attributes`
32. `module-32-clean-dedup-dates`

**Warehouse**

33. `module-33-star-schema-design`
34. `module-34-fact-dimension-load`
35. `module-35-scd-type1-and-type2`
36. `module-36-data-quality-and-capstone`

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
