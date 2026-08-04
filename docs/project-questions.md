# RetailIQ Analytics Platform — 20 Project Questions

The brief: you are the analytics engineer at **RetailIQ**, a retailer selling music (Chinook) and
DVDs (Pagila), with messy e-commerce exports on the side. Ingest, clean, model, and deliver.

These 20 questions are the whole project. They run in order, each producing a real artefact that
the next one builds on — by Q20 you have a loaded warehouse, a tested pipeline, and a business
report. Between them they exercise every SQL topic a senior engineer is expected to know; the
[coverage matrix](#coverage-matrix) at the bottom maps each topic to the question that hits it, so
you can see nothing is skipped.

Each question is deliberately larger than a practice exercise. Treat one as a sitting of a few
hours, not a five-minute query.

## Engine

Write for **PostgreSQL 16** as the primary engine. It is the only one of the candidates that
supports the full surface these questions need — `FILTER`, `GROUPING SETS`, `LATERAL`, `MERGE`,
`jsonb`, ordered-set aggregates, `generate_series`, window `EXCLUDE`, and `TABLESAMPLE` — and
Pagila is a native PostgreSQL dump, so it loads with no translation.

Two practical notes:

- **Chinook ships as SQLite.** Q1 covers moving it into PostgreSQL. Keep the SQLite file around;
  the dialect differences are worth seeing.
- **PostgreSQL cannot read Parquet natively.** For the NYC taxi file use DuckDB
  (`SELECT * FROM 'yellow_tripdata_2024-01.parquet'`), which reads it directly and speaks
  near-identical SQL, or convert it to CSV first. Q14 and Q15 are where it earns its place — 3
  million rows is what makes window-function cost visible in a way 10k rows never will.

Where a question says *portable*, write it so it runs on both PostgreSQL and SQLite, and note in
comments what you had to change. Dialect awareness is part of the job.

## Folder and module map

| # | Folder | Modules | Questions |
| --- | --- | --- | --- |
| 1 | `00-setup/` | setup | Q1 |
| 2 | `01-foundations/` | 01–06 | Q2, Q3 |
| 3 | `02-single-table/` | 07–13 | Q4, Q5, Q6 |
| 4 | `03-joins/` | 14–21 | Q7, Q8 |
| 5 | `04-aggregation/` | 22–27 | Q9, Q10 |
| 6 | `05-subqueries-ctes/` | 28–34 | Q11, Q12 |
| 7 | `06-windows/` | 35–44 | Q13, Q14, Q15 |
| 8 | `07-set-ops/` | 45–47 | Q16 |
| 9 | `08-dml/` | 48–53 | Q17 |
| 10 | `ddl/` | 54–60 | Q18 |
| 11 | `09-etl/` | 61–67 | Q19 |
| 12 | `10-warehouse/` | 68–74 | Q20 |
| 13 | `tests/` | 75–81 | Q20 |
| 14 | `36-capstone-report/` | 83–86 | Q20 |
| 15 | `data/` | — | source data, committed |
| 16 | `queries/` | — | consolidated query library |
| 17 | `docs/` | — | ER diagrams, notes, performance write-ups |

Module 82 is unassigned in the source plan — use it for the pre-capstone dry run.

---

## Q1 — Stand up the platform and inventory what you have

**Ask.** RetailIQ has handed you seven raw sources and no documentation. Get them all queryable in
one PostgreSQL instance and produce an inventory the rest of the project can trust.

**Data.** All of it: Chinook, Pagila, Online Retail, Superstore, HR, NYC taxi, GH Archive.

**Must use.** `CREATE DATABASE`, `CREATE SCHEMA`, `CREATE TABLE`, `COPY`, `\copy`, `psql`
meta-commands, the information schema (`information_schema.tables`, `.columns`,
`pg_catalog.pg_class`), `pg_size_pretty`, `pg_total_relation_size`, `CREATE EXTENSION`.

**Deliverable.** `00-setup/01-load-all.sql`, `00-setup/02-inventory.sql`, and
`docs/data-inventory.md` — one row per table: source, grain, row count, on-disk size, primary key,
and a one-line description. Include a schema-per-source layout (`raw_chinook`, `raw_pagila`,
`raw_files`) so nothing collides.

**Done when.** Every source is queryable from one connection, the inventory is generated *by a
query* rather than typed by hand, and re-running the load is idempotent.

---

## Q2 — Types, casting, and the NULL audit

**Ask.** The CSVs arrived as all-text. Establish what each column really is, and write the
definitive rules for how RetailIQ treats missing data.

**Data.** Online Retail, Superstore, HR, datablist CSVs.

**Must use.** `CAST` / `::`, `pg_typeof`, `NUMERIC` vs `FLOAT` (and why money is never float),
`TO_DATE`, `TO_TIMESTAMP`, `TO_NUMBER`, safe casting with a regex guard or
`CASE WHEN ... ~ '^[0-9.]+$'`, `IS NULL` / `IS NOT NULL`, `IS DISTINCT FROM`, `COALESCE`,
`NULLIF`, `GREATEST` / `LEAST` with NULLs, `ORDER BY ... NULLS FIRST/LAST`, three-valued logic,
and the `NOT IN (NULL)` trap.

**Deliverable.** `01-foundations/01-type-profile.sql` (a query that infers each text column's
true type and reports cast failure counts), `01-foundations/02-null-audit.sql`,
`docs/null-policy.md`.

**Done when.** You can state, per column, the target type and the rule for missing values — and
you have demonstrated with a query why `WHERE col NOT IN (SELECT ... )` silently returns zero rows
when the subquery contains a NULL.

---

## Q3 — Expressions, string, and numeric function drill

**Ask.** Customer names, addresses, and product descriptions are inconsistent. Build the
normalisation expression library the ETL layer will reuse.

**Data.** Online Retail (`Description`, `StockCode`), datablist customers, HR (`Employee_Name`,
which is `"Last, First"`), Pagila `address`.

**Must use.** `||`, `CONCAT`, `CONCAT_WS`, `UPPER`, `LOWER`, `INITCAP`, `TRIM`, `BTRIM`, `LTRIM`,
`RTRIM`, `LPAD`, `RPAD`, `LEFT`, `RIGHT`, `SUBSTRING`, `POSITION`, `STRPOS`, `SPLIT_PART`,
`REPLACE`, `TRANSLATE`, `REVERSE`, `LENGTH`, `CHAR_LENGTH`, `OCTET_LENGTH`, `REPEAT`, `FORMAT`,
`MD5`, `ROUND`, `TRUNC`, `CEIL`, `FLOOR`, `ABS`, `MOD`, `POWER`, `SQRT`, `EXP`, `LN`, `LOG`,
`SIGN`, `DIV`, `WIDTH_BUCKET`, integer-division and rounding-mode gotchas.

**Deliverable.** `01-foundations/03-string-functions.sql`,
`01-foundations/04-numeric-functions.sql`, and a reusable
`queries/lib/normalise.sql` of expressions (`clean_name`, `clean_sku`, `split_person_name`).

**Done when.** `"Adinolfi, Wilson  K"` splits correctly into first/last despite the double space,
and you can explain what `WIDTH_BUCKET` gives you that a `CASE` ladder does not.

---

## Q4 — Filtering, pattern matching, and regular expressions

**Ask.** Fraud and ops need precise slices of the transaction log. Cancelled invoices, suspicious
SKUs, and free-text matching.

**Data.** Online Retail (cancellations are `InvoiceNo` starting `C`), Pagila `film`, Chinook
`Track`.

**Must use.** `WHERE`, `AND` / `OR` / `NOT` and precedence, `BETWEEN` (and its inclusivity),
`IN`, `NOT IN`, `LIKE`, `ILIKE`, `NOT LIKE`, escape characters, `SIMILAR TO`, POSIX regex
`~` `~*` `!~`, `REGEXP_REPLACE`, `REGEXP_MATCHES`, `REGEXP_SPLIT_TO_TABLE`, `SUBSTRING(x FROM
'pattern')`, `ANY` / `ALL` with arrays, `EXISTS` as a filter, `DISTINCT` vs `DISTINCT ON`.

**Deliverable.** `02-single-table/01-filtering.sql`, `02-single-table/02-regex.sql`.

**Done when.** You have quantified the cancellations, isolated non-product `StockCode` values
(postage, manual adjustments, bank charges), and shown a case where `LIKE` and `~` disagree.

---

## Q5 — Dates, times, and the calendar spine

**Ask.** Every report is time-sliced. Build the date dimension the warehouse will use, and settle
fiscal-calendar rules.

**Data.** Online Retail `InvoiceDate`, Superstore `Order Date` / `Ship Date`, Pagila `rental`,
NYC taxi pickup/dropoff, HR hire/termination.

**Must use.** `CURRENT_DATE`, `NOW()`, `CURRENT_TIMESTAMP` vs `clock_timestamp()`, `AGE`,
`DATE_TRUNC`, `EXTRACT`, `DATE_PART`, `INTERVAL` arithmetic, `generate_series` for the spine,
`TO_CHAR` format patterns, `EPOCH`, `OVERLAPS`, `tstzrange` and range containment, time zones
(`AT TIME ZONE`), `ISO` week numbering, month-end and leap-year edge cases, and shipping-lag
calculations.

**Deliverable.** `02-single-table/03-dates.sql`, `ddl/dim_date.sql` — a full date dimension
(day, ISO week, month, quarter, fiscal period, weekend/holiday flags) generated by
`generate_series`, not loaded from a file.

**Done when.** `dim_date` covers every date present across all sources with no gaps, and
ship-lag handles the rows where `Ship Date` precedes `Order Date`.

---

## Q6 — Conditional logic, sorting, and pagination

**Ask.** Build the customer-facing product browser: segmented, sorted, and paged.

**Data.** Chinook `Track` / `Album` / `Genre`, Superstore orders.

**Must use.** `CASE` (simple and searched), nested `CASE`, `COALESCE` as a `CASE` shorthand,
`NULLIF` to dodge divide-by-zero, `ORDER BY` with expressions, multiple keys, `ASC`/`DESC`,
`NULLS FIRST/LAST`, ordering by a `CASE` for custom sort orders, `LIMIT` / `OFFSET`,
`FETCH FIRST n ROWS WITH TIES`, keyset pagination, `DISTINCT ON`, and `TABLESAMPLE`.

**Deliverable.** `02-single-table/04-case-logic.sql`, `02-single-table/05-pagination.sql`,
plus `docs/pagination-notes.md` comparing OFFSET and keyset pagination at depth.

**Done when.** You can show with `EXPLAIN ANALYZE` why `OFFSET 100000` degrades and keyset
pagination does not.

---

## Q7 — The join taxonomy and the fan-out trap

**Ask.** Revenue reported by two teams disagrees by 30%. Find out why, and write the rules.

**Data.** Chinook `Invoice` / `InvoiceLine` / `Track` / `Album` / `Artist`, Pagila
`film` / `film_actor` / `actor` / `film_category`.

**Must use.** `INNER JOIN`, `LEFT` / `RIGHT` / `FULL OUTER JOIN`, `CROSS JOIN`, self-join,
`NATURAL JOIN` (and why to avoid it), `USING` vs `ON`, multi-table joins, join order, the
difference between a filter in `ON` and in `WHERE` for outer joins, and **fan-out**: how joining a
1:N table inflates `SUM`.

**Deliverable.** `03-joins/01-join-types.sql`, `03-joins/02-fanout.sql`,
`docs/fanout-postmortem.md` reproducing the 30% discrepancy and proving the fix.

**Done when.** You can demonstrate the same revenue figure computed three ways — pre-aggregate
then join, join then `SUM(DISTINCT)`, and a correlated scalar subquery — and say which is correct
and why the other two are dangerous.

---

## Q8 — Anti-joins, semi-joins, non-equi joins, and LATERAL

**Ask.** Find what is *missing* and what is *nearby*: customers who never bought, films never
rented, price-band classification, and each customer's most recent orders.

**Data.** Chinook, Pagila, Superstore orders + returns, HR salary bands.

**Must use.** Anti-join three ways (`NOT EXISTS`, `LEFT JOIN ... WHERE IS NULL`, `NOT IN`) and
their NULL behaviour, semi-join via `EXISTS` and `IN`, non-equi joins (`BETWEEN` on a band table,
`<` / `>` joins), self non-equi join for running comparisons, `LATERAL` / `CROSS JOIN LATERAL`
(top-N-per-group before window functions), and `LEFT JOIN LATERAL`.

**Deliverable.** `03-joins/03-anti-semi.sql`, `03-joins/04-non-equi.sql`,
`03-joins/05-lateral.sql`.

**Done when.** All three anti-join formulations return identical counts, and you have documented
the input that makes `NOT IN` diverge.

---

## Q9 — Aggregates, GROUP BY, HAVING, and FILTER

**Ask.** The standard reporting pack: revenue by market, category, and month, with returns netted
out.

**Data.** Superstore orders + returns, Online Retail, Chinook invoices.

**Must use.** `COUNT(*)` vs `COUNT(col)` vs `COUNT(DISTINCT col)`, `SUM`, `AVG`, `MIN`, `MAX`,
`GROUP BY` with expressions and ordinals, `HAVING` vs `WHERE`, the `FILTER (WHERE ...)` clause,
conditional aggregation with `CASE`, `STRING_AGG`, `ARRAY_AGG`, `BOOL_AND` / `BOOL_OR`,
`EVERY`, aggregate `DISTINCT`, `ORDER BY` inside `STRING_AGG`, and empty-group behaviour.

**Deliverable.** `04-aggregation/01-core-aggregates.sql`,
`04-aggregation/02-conditional-agg.sql`.

**Done when.** Return rate by category is computed with `FILTER` *and* with `CASE`, both agree,
and you can say which reads better and why `COUNT(*)` and `COUNT(col)` differ.

---

## Q10 — Multi-level totals and statistical aggregates

**Ask.** Finance wants subtotals at every level in one result set, and the analytics team wants
distributions rather than averages.

**Data.** Superstore, Online Retail, NYC taxi (fare distribution), HR salaries.

**Must use.** `GROUPING SETS`, `ROLLUP`, `CUBE`, the `GROUPING()` function to distinguish real
NULLs from subtotal NULLs, `STDDEV_POP` / `STDDEV_SAMP`, `VARIANCE`, `CORR`, `COVAR_POP`,
`REGR_SLOPE` / `REGR_INTERCEPT` / `REGR_R2`, ordered-set aggregates
`PERCENTILE_CONT` / `PERCENTILE_DISC WITHIN GROUP`, `MODE() WITHIN GROUP`, and hypothetical-set
aggregates (`RANK() WITHIN GROUP`).

**Deliverable.** `04-aggregation/03-grouping-sets.sql`, `04-aggregation/04-statistics.sql`,
`docs/why-median-not-mean.md`.

**Done when.** One query returns category, region, and grand totals distinguishable via
`GROUPING()`, and you have shown a case in the taxi data where the mean fare misleads and the
median does not.

---

## Q11 — Subqueries: scalar, correlated, and quantified

**Ask.** Answer comparative questions — above-average orders, each customer's best purchase,
products outselling their category average.

**Data.** Chinook, Superstore, Online Retail.

**Must use.** Scalar subqueries in `SELECT` / `WHERE` / `HAVING`, correlated subqueries, derived
tables (subquery in `FROM`), `IN` / `NOT IN`, `EXISTS` / `NOT EXISTS`, `ANY` / `SOME` / `ALL`,
row constructors `(a,b) IN (...)`, subqueries in `UPDATE` and `DELETE`, and the correlated-subquery
performance cliff versus a join.

**Deliverable.** `05-subqueries-ctes/01-subqueries.sql`,
`05-subqueries-ctes/02-correlated.sql`.

**Done when.** One correlated subquery is rewritten as a join *and* as a window function, all
three agreeing, with `EXPLAIN ANALYZE` timings for each in `docs/`.

---

## Q12 — CTEs, recursion, and hierarchies

**Ask.** Model the org chart, walk the playlist graph, and refactor the project's worst query into
a readable pipeline.

**Data.** Chinook `Employee` (`ReportsTo` is a true self-referencing FK — 8 rows, 1 root, depth 3),
Pagila `film` / `category`, HR dataset.

**Must use.** `WITH`, multiple chained CTEs, CTEs referenced twice, `MATERIALIZED` /
`NOT MATERIALIZED`, `WITH RECURSIVE`, anchor + recursive terms, `UNION` vs `UNION ALL` in
recursion, depth tracking, path accumulation with arrays, **cycle detection** via a visited-path
array, `generate_series` as a recursive alternative, and recursion depth limits.

**Deliverable.** `05-subqueries-ctes/03-ctes.sql`, `05-subqueries-ctes/04-recursive.sql`,
`docs/org-hierarchy.md`.

**Done when.** The recursive CTE returns each employee with full management chain and depth, it
terminates safely after you deliberately introduce a cycle, and you have documented why the HR
dataset's `ManagerID` **cannot** be used for this: its values run 1–39 while `EmpID` runs
10001–10311, with zero overlap — it is a flat lookup, not a hierarchy.

---

## Q13 — Ranking, top-N per group, and deduplication

**Ask.** Best-selling track per genre, top customer per country, and a defensible dedup of the
messy CSVs.

**Data.** Chinook, Online Retail (5,268 genuinely duplicated rows — verified, not hypothetical),
datablist customers, Superstore.

**Must use.** `ROW_NUMBER`, `RANK`, `DENSE_RANK` and when each is right, `PERCENT_RANK`,
`CUME_DIST`, `NTILE` for quartiles, `PARTITION BY`, `ORDER BY` within `OVER`, the named `WINDOW`
clause, top-N-per-group via `ROW_NUMBER() = 1`, dedup via `ROW_NUMBER()` over a business key,
`DISTINCT ON` as the PostgreSQL shortcut, and why window functions cannot appear in `WHERE`.

**Deliverable.** `06-windows/01-ranking.sql`, `06-windows/02-topn.sql`,
`06-windows/03-dedup.sql`.

**Done when.** Ties are handled explicitly (documented choice of `RANK` vs `ROW_NUMBER`), and the
dedup is reproducible — same input, same surviving row, every run.

---

## Q14 — Navigation functions, frames, and running calculations

**Ask.** Month-over-month growth, running revenue, moving averages, and customer-lifetime running
totals.

**Data.** Online Retail (2010-12-01 to 2011-12-09, so 13 months), Superstore (2023-01-03 to
2026-12-30, four years), NYC taxi (high volume — use it to feel frame cost).

**Must use.** `LAG`, `LEAD` with offset and default, `FIRST_VALUE`, `LAST_VALUE`, `NTH_VALUE`,
aggregate window functions (`SUM`/`AVG`/`COUNT` `OVER`), frame clauses `ROWS BETWEEN` vs
`RANGE BETWEEN` vs `GROUPS BETWEEN`, `UNBOUNDED PRECEDING` / `CURRENT ROW` /
`UNBOUNDED FOLLOWING`, `EXCLUDE CURRENT ROW` / `EXCLUDE TIES`, and the classic `LAST_VALUE`
trap where the default frame returns the current row.

**Deliverable.** `06-windows/04-lag-lead.sql`, `06-windows/05-frames.sql`,
`06-windows/06-running-totals.sql`.

**Done when.** You can demonstrate `ROWS` and `RANGE` producing *different* results on the same
data with tied ordering values, and explain exactly why.

---

## Q15 — Gaps, islands, sessionization, and pivoting

**Ask.** Find consecutive purchase streaks, detect churn gaps, sessionize the GH Archive event
stream, and produce a pivoted management report.

**Data.** Online Retail, GH Archive (180,387 events in one hour), NYC taxi, Superstore.

**Must use.** The gaps-and-islands pattern (`ROW_NUMBER` difference), streak detection,
sessionization with `LAG` + a timeout threshold + a cumulative `SUM` flag, `COUNT(*) FILTER` for
pivoting, `CASE`-based crosstab, the `tablefunc` `crosstab()` function, unpivot via
`LATERAL (VALUES ...)` and `UNNEST`, and dynamic column generation.

**Deliverable.** `06-windows/07-gaps-islands.sql`, `06-windows/08-sessionization.sql`,
`06-windows/09-pivot.sql`.

**Done when.** Sessions are cut at a documented inactivity threshold you justify from the data's
own gap distribution, not a guess.

---

## Q16 — Set operations and reconciliation

**Ask.** Reconcile the customer list across three systems, and prove your warehouse matches
source.

**Data.** Chinook `Customer`, datablist customers, Online Retail `CustomerID`, Superstore
customers.

**Must use.** `UNION` vs `UNION ALL` (and the cost of the implicit dedup), `INTERSECT`,
`INTERSECT ALL`, `EXCEPT` / `EXCEPT ALL`, column count and type compatibility rules, `ORDER BY`
applying to the whole set, set ops inside CTEs, and the symmetric-difference pattern
(`(A EXCEPT B) UNION ALL (B EXCEPT A)`) as a row-level diff.

**Deliverable.** `07-set-ops/01-set-operations.sql`, `07-set-ops/02-reconciliation.sql`.

**Done when.** You have a reusable reconciliation query that takes any two tables and reports
rows-only-in-A, rows-only-in-B, and rows-differing — used again in Q20's tests.

---

## Q17 — DML, MERGE, transactions, and concurrency

**Ask.** Build the loader that RetailIQ runs nightly. It must be safe to re-run and safe to run
while people are querying.

**Data.** Staging tables from Online Retail and Superstore into warehouse tables.

**Must use.** `INSERT` (single, multi-row, `INSERT ... SELECT`), `UPDATE`, `UPDATE ... FROM`,
`DELETE`, `DELETE ... USING`, `RETURNING`, `MERGE` (PostgreSQL 15+), `INSERT ... ON CONFLICT DO
UPDATE` as the upsert alternative, `TRUNCATE` vs `DELETE` (and what each does to sequences, FKs,
triggers, and rollback), `BEGIN` / `COMMIT` / `ROLLBACK`, `SAVEPOINT`, isolation levels
(`READ COMMITTED`, `REPEATABLE READ`, `SERIALIZABLE`), `SELECT ... FOR UPDATE`,
`FOR UPDATE SKIP LOCKED`, deadlock demonstration, and idempotency.

**Deliverable.** `08-dml/01-dml-basics.sql`, `08-dml/02-merge-upsert.sql`,
`08-dml/03-transactions.sql`, `docs/isolation-levels.md`.

**Done when.** The loader runs twice in a row with byte-identical end state, and you have
demonstrated a phantom read under `READ COMMITTED` that does not occur under `REPEATABLE READ`
(two `psql` sessions, transcript in `docs/`).

---

## Q18 — Schema, constraints, views, indexes, and query plans

**Ask.** Harden the warehouse schema and make the slow report fast.

**Data.** Your own warehouse tables plus Pagila for realistic index work.

**Must use.** `CREATE` / `ALTER` / `DROP TABLE`, `PRIMARY KEY`, `FOREIGN KEY` with
`ON DELETE CASCADE` / `SET NULL` / `RESTRICT`, `UNIQUE`, `CHECK`, `NOT NULL`, `DEFAULT`,
`GENERATED ALWAYS AS IDENTITY`, generated/computed columns, `DOMAIN`, deferrable constraints,
temp and unlogged tables, `CREATE VIEW`, updatable views, `WITH CHECK OPTION`,
`MATERIALIZED VIEW` + `REFRESH` (and `CONCURRENTLY`), B-tree / partial / expression / composite /
covering (`INCLUDE`) indexes, GIN for `jsonb` and full-text, `EXPLAIN` vs `EXPLAIN (ANALYZE,
BUFFERS)`, reading the plan tree, seq scan vs index scan vs index-only scan, nested loop vs hash
vs merge join, `ANALYZE` and statistics, and table partitioning by range.

**Deliverable.** `ddl/01-schema.sql`, `ddl/02-constraints.sql`, `ddl/03-views.sql`,
`ddl/04-indexes.sql`, `docs/query-tuning.md`.

**Done when.** `docs/query-tuning.md` shows three queries with before/after plans and real
timings, including **one case where adding an index made things worse** — and explains it.

---

## Q19 — The ETL pipeline: ingest, parse, clean, dedup

**Ask.** Turn the raw mess into trustworthy staging tables. This is the heart of the project.

**Data.** Online Retail — 541,909 rows, and the mess is real and measured:

| Defect | Rows | Share |
| --- | --- | --- |
| Blank `CustomerID` | 135,080 | 24.9% |
| Negative `Quantity` (returns) | 10,624 | 2.0% |
| `C`-prefixed `InvoiceNo` (cancellations) | 9,288 | 1.7% |
| Fully duplicated rows | 5,268 | 1.0% |

Plus Superstore, HR (BOM in header, 8 blank `ManagerID`, 23 IDs mapping to 21 names), GH Archive
(nested JSON), datablist CSVs.

Note the trap: negative `Quantity` (10,624) and `C` invoices (9,288) do not agree. Reconciling
that difference is part of the work.

**Must use.** `COPY` with options, error handling on bad rows, all-text landing tables then typed
staging, safe casting, `REGEXP_REPLACE` for key-value parsing, `SPLIT_PART`, `STRING_TO_ARRAY`,
`UNNEST`, `jsonb` operators `->` `->>` `#>` `#>>`, `jsonb_array_elements`,
`jsonb_each`, `jsonb_build_object`, `jsonb_agg`, `jsonb_path_query`, GIN indexing on `jsonb`,
array operators and `ANY`, deduplication with `ROW_NUMBER`, surrogate key generation, watermark
columns, and incremental vs full reload.

**Deliverable.** `09-etl/01-load-raw.sql`, `09-etl/02-parse-strings.sql`,
`09-etl/03-parse-json.sql`, `09-etl/04-clean-dedup.sql`, `docs/data-cleaning-decisions.md`.

**Done when.** Every cleaning decision is written down with its row-count impact — how many rows
dropped, imputed, or corrected, and why. A reviewer must be able to disagree with a choice and see
exactly what it cost.

---

## Q20 — Warehouse, data quality, and the capstone report

**Ask.** Deliver the star schema, the tests that guard it, and the business report RetailIQ
actually reads. This is the final artefact.

**Data.** Everything.

**Must use.**

*Modelling:* star schema, grain declaration, fact vs dimension, surrogate vs natural keys,
conformed dimensions, degenerate dimensions, junk dimensions, bridge tables for many-to-many
(film↔actor), transaction vs periodic-snapshot vs accumulating-snapshot facts, factless facts,
`dim_date` from Q5, **SCD Type 1** (overwrite), **SCD Type 2** (`valid_from` / `valid_to` /
`is_current`, with the `MERGE` logic to maintain it), SCD Type 3, and late-arriving dimensions.

*Testing:* not-null, uniqueness, referential integrity, accepted values, range, freshness, and
row-count reconciliation against source (reuse Q16's diff query). Each test returns zero rows on
pass.

*Analytics:* cohort retention, funnel conversion, RFM segmentation, customer LTV, churn, ABC/Pareto
(80/20), market-basket affinity, YoY / MoM / YTD, market share, and a KPI summary.

**Deliverable.** `10-warehouse/01-dimensions.sql`, `10-warehouse/02-facts.sql`,
`10-warehouse/03-scd2.sql`, `tests/*.sql` (one file per test class),
`tests/run-all.sql`, `queries/` (the consolidated analytics library),
`docs/erd.md`, and `36-capstone-report/report.md`.

**Done when.** `tests/run-all.sql` passes on a freshly loaded warehouse; an SCD2 dimension
correctly carries history through a simulated attribute change; and `report.md` states five
business findings, each with the query that produced it, the number, and a recommendation. Written
for a reader who does not know SQL.

---

## Coverage matrix

Every topic, and the question that covers it.

| Area | Topic | Q |
| --- | --- | --- |
| **Setup** | Instance, schemas, extensions, bulk load, catalogs | 1 |
| **Types** | Numeric, text, date/time, boolean, `jsonb`, arrays, UUID, domains | 2, 19 |
| | `CAST`, `::`, safe casting, `TO_DATE`/`TO_NUMBER`, `pg_typeof` | 2 |
| **NULL** | Three-valued logic, `IS NULL`, `IS DISTINCT FROM` | 2 |
| | `COALESCE`, `NULLIF`, `NULLS FIRST/LAST`, `NOT IN` trap | 2, 6, 8 |
| **Operators** | Arithmetic, comparison, logical, precedence, `||` | 3, 4 |
| **Strings** | 25+ functions incl. regex, `SPLIT_PART`, `TRANSLATE`, `FORMAT` | 3, 4 |
| **Numerics** | `ROUND`, `TRUNC`, `MOD`, `POWER`, `LOG`, `WIDTH_BUCKET` | 3 |
| **Dates** | `DATE_TRUNC`, `EXTRACT`, `INTERVAL`, `AGE`, `generate_series`, time zones, `OVERLAPS` | 5 |
| **Filtering** | `WHERE`, `BETWEEN`, `IN`, `LIKE`/`ILIKE`, `SIMILAR TO`, POSIX regex | 4 |
| **Conditionals** | `CASE` simple/searched/nested | 6, 9 |
| **Sorting** | Multi-key, expression, custom `CASE` order, `NULLS` placement | 6 |
| **Paging** | `LIMIT`/`OFFSET`, `FETCH ... WITH TIES`, keyset, `DISTINCT ON`, `TABLESAMPLE` | 6 |
| **Joins** | Inner, left, right, full, cross, self, natural, `USING` vs `ON` | 7 |
| | Fan-out inflation and its three fixes | 7 |
| | Anti-join, semi-join, non-equi, `LATERAL` | 8 |
| **Aggregation** | `COUNT`/`SUM`/`AVG`/`MIN`/`MAX`, `DISTINCT`, `GROUP BY`, `HAVING` | 9 |
| | `FILTER`, conditional agg, `STRING_AGG`, `ARRAY_AGG`, `BOOL_AND/OR` | 9 |
| | `GROUPING SETS`, `ROLLUP`, `CUBE`, `GROUPING()` | 10 |
| | `STDDEV`, `VARIANCE`, `CORR`, `REGR_*`, percentiles, `MODE`, ordered-set | 10 |
| **Subqueries** | Scalar, correlated, derived tables, `EXISTS`, `ANY`/`ALL`, row constructors | 11 |
| **CTEs** | `WITH`, chaining, `MATERIALIZED`, `RECURSIVE`, cycle detection, paths | 12 |
| **Windows** | `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `PERCENT_RANK`, `CUME_DIST`, `NTILE` | 13 |
| | `LAG`, `LEAD`, `FIRST_VALUE`, `LAST_VALUE`, `NTH_VALUE` | 14 |
| | `ROWS`/`RANGE`/`GROUPS` frames, `EXCLUDE`, named `WINDOW` | 13, 14 |
| | Top-N per group, dedup, running totals, moving averages | 13, 14 |
| | Gaps and islands, sessionization | 15 |
| **Pivot** | Conditional agg, `crosstab()`, unpivot via `VALUES`/`UNNEST` | 15 |
| **Set ops** | `UNION`(`ALL`), `INTERSECT`(`ALL`), `EXCEPT`(`ALL`), symmetric diff | 16 |
| **DML** | `INSERT`, `UPDATE ... FROM`, `DELETE ... USING`, `RETURNING` | 17 |
| | `MERGE`, `ON CONFLICT` upsert, `TRUNCATE` vs `DELETE` | 17 |
| **Transactions** | `BEGIN`/`COMMIT`/`ROLLBACK`, `SAVEPOINT`, isolation levels | 17 |
| | `FOR UPDATE`, `SKIP LOCKED`, deadlocks, idempotency | 17 |
| **DDL** | `CREATE`/`ALTER`/`DROP`, identity, generated columns, domains, temp/unlogged | 18 |
| **Constraints** | PK, FK + referential actions, `UNIQUE`, `CHECK`, `NOT NULL`, `DEFAULT`, deferrable | 18 |
| **Views** | Views, updatable views, `WITH CHECK OPTION`, matviews, `REFRESH CONCURRENTLY` | 18 |
| **Indexes** | B-tree, composite, partial, expression, covering, GIN | 18 |
| **Performance** | `EXPLAIN (ANALYZE, BUFFERS)`, scan types, join algorithms, statistics, partitioning | 18 |
| **ETL** | `COPY`, landing→staging, safe cast, dedup, surrogate keys, watermarks, incremental | 19 |
| **Semi-structured** | `jsonb` operators, `jsonb_array_elements`, `jsonb_path_query`, GIN, arrays, `UNNEST` | 19 |
| **Modelling** | Star schema, grain, conformed/degenerate/junk dims, bridge, fact types | 20 |
| | SCD Type 1, Type 2, Type 3, late-arriving dimensions | 20 |
| **Data quality** | Not-null, unique, referential, accepted values, range, freshness, reconciliation | 20 |
| **Analytics** | Cohort, funnel, RFM, LTV, churn, Pareto, market basket, YoY/MoM/YTD | 20 |

## Working notes

- Commit at the end of each question, not in one batch at the end.
- Every query file starts with a comment: the business question, the assumption, and the expected
  row count.
- When a query returns a surprising number, write down *why* in `docs/`. That file is the actual
  evidence of seniority — anyone can write `GROUP BY`.
