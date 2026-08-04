-- Q1 deliverable: inventory every table in the warehouse.
--
-- Business question: we were handed seven undocumented sources. What do we actually have,
-- how big is each thing, and what identifies a row?
--
-- Engine: DuckDB. Run against data/retailiq.duckdb.
-- Expected: 93 tables, 4,196,602 rows, 3 schemas.
--
-- Nothing here is typed by hand. The catalog is queried, and where a plain query cannot
-- reach (row counts and key detection need one query *per table*) SQL is generated from the
-- catalog and then executed. That generate-then-run pattern is the point of section 3.

-- ---------------------------------------------------------------------------
-- 1. What schemas and tables exist, and how wide is each table
-- ---------------------------------------------------------------------------
SELECT
    t.schema_name,
    t.table_name,
    COUNT(c.column_name)      AS column_count,
    t.estimated_size          AS row_count
FROM duckdb_tables() t
JOIN duckdb_columns() c
  ON c.schema_name = t.schema_name
 AND c.table_name  = t.table_name
GROUP BY t.schema_name, t.table_name, t.estimated_size
ORDER BY t.schema_name, row_count DESC;

-- estimated_size is a stored statistic, not a scan. On a freshly built database it matches
-- COUNT(*) exactly (verified across all 93 tables), but it is an estimate by contract - after
-- heavy updates it can drift. Section 3 counts for real.

-- ---------------------------------------------------------------------------
-- 2. Schema-level summary
-- ---------------------------------------------------------------------------
SELECT
    schema_name,
    COUNT(*)                  AS tables,
    SUM(estimated_size)       AS rows
FROM duckdb_tables()
GROUP BY schema_name
ORDER BY rows DESC;

-- ---------------------------------------------------------------------------
-- 3. Exact row counts, by generating one COUNT(*) per table and running the result
-- ---------------------------------------------------------------------------
-- Run this first. It returns a single string: a complete SQL statement.
SELECT string_agg(
           format(
               'SELECT ''%s'' AS schema_name, ''%s'' AS table_name, COUNT(*) AS row_count FROM "%s"."%s"',
               schema_name, table_name, schema_name, table_name),
           E'\nUNION ALL\n'
           ORDER BY schema_name, table_name)
       AS generated_sql
FROM duckdb_tables();

-- Then copy the output and execute it. The result is exact counts for every table,
-- with no table names typed by hand - add a source and the query keeps working.

-- ---------------------------------------------------------------------------
-- 4. Candidate keys: which single columns could identify a row
-- ---------------------------------------------------------------------------
-- A column can be the key only if it is unique AND never null. Same trick: generate,
-- then run.
SELECT string_agg(
           format(
               'SELECT ''%s.%s'' AS tbl, ''%s'' AS col, COUNT(DISTINCT "%s") AS distinct_vals, '
               'COUNT(*) AS rows, COUNT(*) FILTER (WHERE "%s" IS NULL) AS nulls FROM "%s"."%s"',
               schema_name, table_name, column_name, column_name, column_name,
               schema_name, table_name),
           E'\nUNION ALL\n')
       AS generated_sql
FROM duckdb_columns()
WHERE schema_name = 'chinook';   -- widen or drop this filter as needed; all 93 tables is slow

-- A column is a candidate key where distinct_vals = rows AND nulls = 0.
--
-- Important: unique is not the same as key. pagila.film has five columns that pass this test
-- (film_id, title, description, last_update, fulltext) but only film_id is the primary key.
-- The others are unique by accident of this 1,000-row extract and would collide on a real
-- catalogue. A candidate key is a hypothesis; confirm it against what the column *means*.

-- ---------------------------------------------------------------------------
-- 5. Tables with no single-column key - check for a composite one
-- ---------------------------------------------------------------------------
-- Four tables have no single column that identifies a row. Each fails differently.

-- A junction table: neither column alone is unique, the pair is. This is a real composite key.
SELECT COUNT(*) AS rows,
       COUNT(DISTINCT (PlaylistId, TrackId)) AS distinct_pairs
FROM chinook.PlaylistTrack;                       -- 8,715 = 8,715, composite key confirmed

-- A transaction log: even the natural pair repeats, because one invoice can list the same
-- product on more than one line. There is no natural key; the warehouse must supply one.
SELECT COUNT(*) AS rows,
       COUNT(DISTINCT (InvoiceNo, StockCode)) AS distinct_pairs
FROM raw.online_retail;                           -- 541,909 vs 531,225: 10,684 repeats

-- An event stream that *should* have a unique id, and very nearly does.
SELECT COUNT(*) AS rows,
       COUNT(DISTINCT id) AS distinct_ids,
       COUNT(*) - COUNT(DISTINCT id) AS duplicate_ids
FROM raw.gh_events;                               -- 180,387 vs 180,386: exactly one duplicate

-- Find the offender.
SELECT id, COUNT(*) AS n
FROM raw.gh_events
GROUP BY id
HAVING COUNT(*) > 1;
