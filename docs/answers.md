# RetailIQ — Answer Sheet

One entry per question from [project-questions.md](project-questions.md).

**Q1 is worked in full as the example.** Q2–Q20 are templates for you to fill in as you go.
Copy the shape of Q1: explain it plainly first, then show the SQL, then show what actually came
back, then say what you concluded. The explanation matters as much as the query — a result nobody
can interpret is not an answer.

Q1 also includes a **plain-English section** written for someone with no technical background at
all. You do not have to write one of those for every question, but doing it for the two or three
that matter most is the single best test of whether you actually understand them.

---

# Q1 — Stand up the platform and inventory what you have

**Status:** Complete — worked example
**Modules:** `61` Bulk loading and landing tables
**Files:** [`00-setup/build_warehouse.py`](../00-setup/build_warehouse.py),
[`00-setup/02-inventory.sql`](../00-setup/02-inventory.sql),
[`docs/data-inventory.md`](data-inventory.md)

## Part 1 — In plain English, from zero

*Read this even if you have never seen a database. Nothing below assumes you have.*

### What we were given

Seven piles of data, from seven different places, in five different file formats, with no
documentation. Music sales. DVD rentals. An online gift shop's order history. Office-supply
orders. An HR record. A month of New York taxi journeys. An hour of activity from GitHub.

They arrived the way real data arrives: as files someone emailed you, in whatever shape the
system that produced them happened to spit out.

### Why that is a problem

Imagine seven filing cabinets delivered to your office. Each is locked in a different way. One
opens with a key, one with a combination, one is in a language you do not read. You cannot answer
even a simple question — *how many customers do we have?* — because the customers are spread
across three of the cabinets and you cannot open two of them.

Before you can analyse anything, everything has to be in one place, openable the same way.

### What a database actually is

A **database** is a filing cabinet for data. Inside it are **tables**.

A **table** is just a grid, exactly like a spreadsheet:

- a **column** is a field — `first_name`, `price`, `order_date`
- a **row** is one record — one customer, one order, one taxi journey

That is genuinely all a table is. If you can picture a spreadsheet, you can picture a table.

A **schema** is a folder that groups related tables. We made three:

| Folder | What's in it |
| --- | --- |
| `chinook` | the music shop |
| `pagila` | the DVD rental shop |
| `raw` | everything that arrived as a loose file |

So `chinook.Track` means: *the Track table, in the chinook folder.* Same idea as
`Documents/Invoices/March.xlsx`.

### What we did

We wrote a program that opens all seven sources and copies everything into one database file.
It runs in about 100 seconds and produces `data/retailiq.duckdb` — one file, containing
everything.

The result:

> **93 tables. 4,196,602 rows. One place. One way in.**

Now *how many customers do we have?* is a question you can actually ask.

### Then we counted what we had

Getting the data in is not the same as knowing what you have. So we ran a second step: walk every
one of the 93 tables and record, for each, how many rows, how many columns, and — the important
one — **what makes a row unique**.

### The one idea worth slowing down for: what makes a row unique

Every table should have something that tells rows apart. A person has a passport number. A car has
a registration plate. Two people can share a name and a birthday; they cannot share a passport
number.

In data this is called the **primary key** — the column whose value is different on every single
row, and never blank. It matters because without it you cannot safely say "update *this* customer"
or "count each order once". You would have no way to point at one row and be sure you meant only
that one.

So we checked all 93 tables for it. **89 had one. Four did not** — and each was interesting:

**1. The music playlists table.** A playlist contains many songs; a song appears on many
playlists. Neither column alone is unique — playlist 5 appears hundreds of times, song 20 appears
on dozens of playlists. But the *pair* is unique: song 20 appears on playlist 5 exactly once.
All 8,715 rows have a different pair.

That is normal and correct. It is called a **composite key** — it takes two columns together to
identify a row. Nothing is wrong here.

**2. The online gift shop's order lines.** We expected invoice number + product code to be
unique — surely a product appears once per invoice? It does not. 541,909 rows, but only 531,225
different combinations. **10,684 rows repeat.**

Sometimes that is legitimate: a till operator scans an item, adds more later, and it lands as a
second line. Sometimes it is a genuine duplicate that should never have been recorded. You cannot
tell which from the number alone — but you now know the question exists, and roughly how much of
the data it touches. Discovering that *before* building reports on it is the whole point.

**3. The taxi journeys.** No ID at all. 2,964,624 journeys and nothing to name one by. That is
normal for machine-generated event data — nobody assigned journey numbers, the meter just wrote a
line each time. If we need to identify one, we have to invent an ID ourselves.

**4. GitHub activity — the interesting one.** Every GitHub event carries a unique ID. We had
180,387 events. We found **180,386 different IDs.**

One duplicate. In 180,387 rows.

Nobody finds that by looking. A person could scroll that file for a week and miss it. It took one
query and a few seconds — and it is exactly the kind of thing that, left undiscovered, makes a
report quietly wrong in a way nobody can explain six months later.

### A trap we walked into on purpose

Our check asked: *is this column unique and never blank?* For the DVD films table, five columns
passed — including the film's **title** and its **description**.

Does that make the title a valid ID for a film? No. It passed only because this sample has 1,000
films and no two happen to share a title. Load the real catalogue and you will have two films
called *The Italian Job*, and anything built on titles-as-IDs breaks.

The lesson generalises: **the data can only tell you a column is unique so far. It cannot tell you
it will stay unique.** That takes knowing what the column means. A computer found five candidates;
judgement narrowed it to one.

### Where that leaves us

We can now query all seven sources together, we know the size and shape of all 93 tables, and we
have found four specific problems before writing a single report. Everything after this builds on
that foundation.

## Part 2 — The technical answer

### Approach

Two steps, deliberately separated:

1. **Load** — `00-setup/build_warehouse.py` reads all seven sources into `data/retailiq.duckdb`.
2. **Inventory** — `00-setup/02-inventory.sql` interrogates the catalog. Nothing typed by hand.

Row counts and key detection need one query *per table*, which plain SQL cannot express over a
dynamic table list. Rather than typing 93 queries, the SQL **generates SQL** from the catalog,
which is then executed:

```sql
SELECT string_agg(
           format('SELECT ''%s'' AS schema_name, ''%s'' AS table_name, COUNT(*) AS row_count FROM "%s"."%s"',
                  schema_name, table_name, schema_name, table_name),
           E'\nUNION ALL\n' ORDER BY schema_name, table_name)
FROM duckdb_tables();
```

Add a source tomorrow and the inventory still works, with no edit.

### Result

| Schema | Tables | Rows | Source |
| --- | ---: | ---: | --- |
| `chinook` | 11 | 15,607 | SQLite, attached and copied |
| `pagila` | 71 | 173,270 | parsed from a PostgreSQL dump |
| `raw` | 11 | 4,007,725 | CSV, Parquet, gzipped JSON |
| **Total** | **93** | **4,196,602** | |

Full table-by-table listing: [`docs/data-inventory.md`](data-inventory.md).

### Findings

**Catalog statistics matched reality.** `duckdb_tables().estimated_size` equalled `COUNT(*)`
on all 93 tables. It is still an estimate by contract — it can drift after heavy DML — so the
inventory counts for real and uses the statistic only for the fast overview.

**Four tables have no single-column key**, each failing differently:

| Table | Rows | Diagnosis |
| --- | ---: | --- |
| `chinook.PlaylistTrack` | 8,715 | Composite key `(PlaylistId, TrackId)` — 8,715 distinct pairs. Correct by design. |
| `raw.online_retail` | 541,909 | `(InvoiceNo, StockCode)` yields 531,225 — **10,684 repeats**. No natural key; needs a surrogate. |
| `raw.taxi_trips` | 2,964,624 | Event stream, no identifier at all. Surrogate required. |
| `raw.gh_events` | 180,387 | 180,386 distinct `id` — **exactly one duplicate**. |

**Uniqueness is not keyhood.** `pagila.film` reports five candidate keys — `film_id`, `title`,
`description`, `last_update`, `fulltext`. Only `film_id` is real. The others are artefacts of a
1,000-row sample. A candidate key is a hypothesis to test against meaning, not a conclusion.

**Two tables have an awkward grain:**

- `pagila.payment` — the source partitions it into 55 monthly tables. The loader unions them
  (51,061 rows) and keeps the partitions, so partition pruning can be compared against the union.
- `raw.gh_events` — one row per event, but each carries a nested JSON payload whose shape varies
  by event type. Flat on the surface, hierarchical underneath. Q19 deals with it.

### Done-when check

| Criterion | Status |
| --- | --- |
| Every source queryable from one connection | Yes — 93 tables, one file |
| Inventory generated by query, not by hand | Yes — catalog-driven, generate-then-run |
| Grain stated for all 93 tables | Yes — see `data-inventory.md` |
| The two awkward grains identified | Yes — `pagila.payment`, `raw.gh_events` |

### What carries forward

- `raw.online_retail` and `raw.taxi_trips` need surrogate keys → Q19
- The duplicate `gh_events` id needs a dedup rule → Q13, Q19
- Every `pagila.*` and CSV column is `VARCHAR` and needs typing → Q2
- `pagila.payment` partitions are a ready-made partition-pruning comparison → Q18

---

# Q2 — Types, casting, and the NULL audit

**Status:** Not started
**Modules:** `02` Numeric, text and boolean types · `03` Date, time and interval types ·
`04` Casting, coercion and TRY_CAST · `05` NULL semantics, COALESCE, NULLIF
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| Target type stated per column | |
| Missing-value rule stated per column | |
| `NOT IN` + NULL trap demonstrated | |

## What carries forward

---

# Q3 — Expressions, string, and numeric function drill

**Status:** Not started
**Modules:** `01` SELECT, projection, aliases and literals · `06` String and numeric function library
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| `"Adinolfi, Wilson  K"` splits despite the double space | |
| `WIDTH_BUCKET` vs a `CASE` ladder explained | |

## What carries forward

---

# Q4 — Filtering, pattern matching, and regular expressions

**Status:** Not started
**Modules:** `07` WHERE, comparison and logical operators · `08` BETWEEN, IN and quantified
predicates · `09` LIKE, ILIKE and pattern matching · `10` Regular expressions and regex extraction
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| Cancellations quantified | |
| Non-product `StockCode` values isolated | |
| A case where `LIKE` and regex disagree | |

## What carries forward

---

# Q5 — Dates, times, and the calendar spine

**Status:** Not started
**Modules:** `11` Date arithmetic, DATE_TRUNC, EXTRACT · `12` Calendar spine with generate_series
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| `dim_date` covers every date across all sources, no gaps | |
| Ship-lag handles ship-before-order rows | |

## What carries forward

---

# Q6 — Conditional logic, sorting, and pagination

**Status:** Not started
**Modules:** `13` CASE logic, sorting and pagination
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| `OFFSET` degradation shown with `EXPLAIN ANALYZE` | |
| Keyset pagination shown not to degrade | |

## What carries forward

---

# Q7 — The join taxonomy and the fan-out trap

**Status:** Not started
**Modules:** `14` INNER JOIN and join fundamentals · `15` LEFT, RIGHT and FULL OUTER JOIN ·
`16` ON versus WHERE in outer joins · `17` CROSS JOIN and Cartesian products · `18` Self joins ·
`19` Fan-out: how 1:N joins inflate aggregates
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| Revenue computed three ways | |
| Correct method identified, other two explained | |

## What carries forward

---

# Q8 — Anti-joins, semi-joins, non-equi joins, and LATERAL

**Status:** Not started
**Modules:** `20` Anti-joins and semi-joins · `21` Non-equi joins and LATERAL
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| Three anti-join forms return identical counts | |
| Input that makes `NOT IN` diverge documented | |

## What carries forward

---

# Q9 — Aggregates, GROUP BY, HAVING, and FILTER

**Status:** Not started
**Modules:** `22` COUNT, SUM, AVG, MIN, MAX · `23` GROUP BY and grouping semantics ·
`24` HAVING versus WHERE · `25` FILTER and conditional aggregation
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| Return rate computed with `FILTER` and with `CASE`, agreeing | |
| `COUNT(*)` vs `COUNT(col)` difference explained | |

## What carries forward

---

# Q10 — Multi-level totals and statistical aggregates

**Status:** Not started
**Modules:** `26` GROUPING SETS, ROLLUP, CUBE · `27` Statistical and ordered-set aggregates
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| One query returns category, region and grand totals via `GROUPING()` | |
| Taxi median 12.80 vs mean 18.66 explained with the distribution | |

## What carries forward

---

# Q11 — Subqueries: scalar, correlated, and quantified

**Status:** Not started
**Modules:** `28` Scalar and derived-table subqueries · `29` Correlated subqueries ·
`30` IN, NOT IN and the NULL trap · `31` EXISTS, NOT EXISTS, ANY, ALL
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| Same answer via correlated subquery, join, and window function | |
| `EXPLAIN ANALYZE` timings for all three recorded | |

## What carries forward

---

# Q12 — CTEs, recursion, and hierarchies

**Status:** Not started
**Modules:** `32` Common table expressions · `33` Recursive CTEs and hierarchies ·
`34` Cycle detection and path accumulation
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| Full management chain and depth returned | |
| Terminates safely after a cycle is introduced | |
| Documented why HR `ManagerID` cannot be used | |

## What carries forward

---

# Q13 — Ranking, top-N per group, and deduplication

**Status:** Not started
**Modules:** `35` OVER, PARTITION BY, window basics · `36` ROW_NUMBER, RANK, DENSE_RANK ·
`37` NTILE, PERCENT_RANK, CUME_DIST · `38` Top-N per group and deduplication
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| Tie handling chosen and justified | |
| Dedup reproducible — same input, same survivor | |

## What carries forward

---

# Q14 — Navigation functions, frames, and running calculations

**Status:** Not started
**Modules:** `39` LAG and LEAD · `40` FIRST_VALUE, LAST_VALUE, NTH_VALUE ·
`41` Frame clauses: ROWS, RANGE, GROUPS · `42` Running totals and moving averages
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| `ROWS` and `RANGE` shown to differ on tied values | |
| The difference explained | |

## What carries forward

---

# Q15 — Gaps, islands, sessionization, and pivoting

**Status:** Not started
**Modules:** `43` Gaps, islands and streaks · `44` Sessionization and pivoting
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| Session timeout justified from the gap distribution | |

## What carries forward

---

# Q16 — Set operations and reconciliation

**Status:** Not started
**Modules:** `45` UNION and UNION ALL · `46` INTERSECT and EXCEPT ·
`47` Reconciliation and symmetric difference
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| Reusable diff query: only-in-A, only-in-B, differing | |

## What carries forward

---

# Q17 — DML, MERGE, transactions, and concurrency

**Status:** Not started
**Modules:** `48` INSERT and INSERT ... SELECT · `49` UPDATE and UPDATE ... FROM ·
`50` DELETE, DELETE ... USING, TRUNCATE · `51` MERGE and upserts ·
`52` Transactions, COMMIT, ROLLBACK, SAVEPOINT · `53` Isolation levels, locking, idempotency
**Files:**

> Modules 52–53 need PostgreSQL: DuckDB is single-writer, so isolation levels, `SKIP LOCKED`
> and deadlocks cannot be demonstrated. Do the rest on DuckDB and note this as deferred.

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| Loader runs twice with identical end state | |
| Phantom read under `READ COMMITTED`, absent under `REPEATABLE READ` | deferred — needs PostgreSQL |

## What carries forward

---

# Q18 — Schema, constraints, views, indexes, and query plans

**Status:** Not started
**Modules:** `54` CREATE, ALTER, DROP TABLE · `55` Primary keys, foreign keys, referential
actions · `56` UNIQUE, CHECK, NOT NULL, DEFAULT · `57` Identity columns, sequences, generated
columns · `58` Views and updatable views · `59` Materialized views and refresh strategies ·
`60` Indexes, query plans and EXPLAIN
**Files:**

> Module 59 and GIN indexes need PostgreSQL. `CREATE TABLE AS` is the DuckDB stand-in for a
> materialized view.

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| Three queries with before/after plans and timings | |
| One case where an index made things **worse**, explained | |

## What carries forward

---

# Q19 — The ETL pipeline: ingest, parse, clean, dedup

**Status:** Not started
**Modules:** `62` Type profiling and safe casting · `63` String parsing and key-value extraction ·
`64` JSON and semi-structured data · `65` Arrays, lists and UNNEST ·
`66` Deduplication and survivorship rules · `67` Date cleaning and incremental loads
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| Every cleaning decision recorded with its row-count impact | |
| A reviewer could disagree and see what the choice cost | |

## What carries forward

---

# Q20 — Warehouse, data quality, and the capstone report

**Status:** Not started
**Modules:** `68`–`74` warehouse · `75`–`81` tests · `82` integration rehearsal ·
`83`–`86` capstone report (19 modules)
**Files:**

## Approach

## Result

## Findings

## Done-when check

| Criterion | Status |
| --- | --- |
| `tests/run-all.sql` passes on a freshly loaded warehouse | |
| SCD2 dimension carries history through a simulated change | |
| Five business findings, each with query, number and recommendation | |
| Report readable by someone who does not know SQL | |

## What carries forward

---

## Progress

| Q | Topic | Modules | Status |
| --- | --- | ---: | --- |
| 1 | Platform and inventory | 1 | **Complete** |
| 2 | Types, casting, NULL | 4 | Not started |
| 3 | String and numeric functions | 2 | Not started |
| 4 | Filtering and regex | 4 | Not started |
| 5 | Dates and calendar spine | 2 | Not started |
| 6 | CASE, sorting, pagination | 1 | Not started |
| 7 | Joins and fan-out | 6 | Not started |
| 8 | Anti/semi/non-equi/LATERAL | 2 | Not started |
| 9 | Aggregates and GROUP BY | 4 | Not started |
| 10 | Multi-level totals, statistics | 2 | Not started |
| 11 | Subqueries | 4 | Not started |
| 12 | CTEs and recursion | 3 | Not started |
| 13 | Ranking, top-N, dedup | 4 | Not started |
| 14 | Navigation, frames, running | 4 | Not started |
| 15 | Gaps, islands, pivot | 2 | Not started |
| 16 | Set operations | 3 | Not started |
| 17 | DML and transactions | 6 | Not started |
| 18 | DDL, indexes, plans | 7 | Not started |
| 19 | ETL pipeline | 6 | Not started |
| 20 | Warehouse, tests, capstone | 19 | Not started |

**1 of 20 complete · 1 of 86 modules**
