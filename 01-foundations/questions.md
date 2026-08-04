# 01-foundations — 20 practice questions

Modules 01–06. Every question runs against `data/retailiq.duckdb`; build it first with
`python 00-setup/build_warehouse.py`.

Attempt each before opening the solution. Every solution below has been executed against the
real data — the row count under each one is what it actually returned.

| # | Module | Question |
| --- | --- | --- |
| 1 | `01` | The shop-floor price list |
| 2 | `01` | A report header from nothing |
| 3 | `01` | Which countries do we bill? |
| 4 | `01` | Track length in minutes |
| 5 | `02` | Flagging long tracks |
| 6 | `02` | Why money is never a float |
| 7 | `02` | The longest product name |
| 8 | `03` | Sales by calendar year |
| 9 | `03` | The month after a launch |
| 10 | `03` | Staff tenure |
| 11 | `04` | Summing a number that is stored as text |
| 12 | `04` | Finding the values that will not cast |
| 13 | `04` | Superstore revenue, from text |
| 14 | `04` | Parsing a US date written as text |
| 15 | `05` | The missing composers |
| 16 | `05` | A safe division |
| 17 | `05` | The NOT IN trap |
| 18 | `06` | Splitting 'Last, First' names |
| 19 | `06` | Normalising messy product descriptions |
| 20 | `06` | Fare bands for the taxi data |

---

## Module 01 — SELECT, projection, aliases and literals

### Q1. The shop-floor price list

The catalogue team is printing a price list. From `chinook.Track`, return the track name, its unit price, and the price in cents as a whole number, for the 20 most expensive tracks. Name the columns `track`, `price_usd` and `price_cents`.

<details>
<summary>Solution</summary>

```sql
SELECT Name          AS track,
       UnitPrice     AS price_usd,
       CAST(UnitPrice * 100 AS INTEGER) AS price_cents
FROM chinook.Track
ORDER BY UnitPrice DESC, Name
LIMIT 20
```

**Returns:** 20 rows

**Why it works.** `AS` renames a column for output only - the table is untouched. The third column is an *expression*, computed per row. Ordering by `Name` as a tiebreak makes the result deterministic; without it, the 20 rows you get from a price tie are arbitrary.

</details>

### Q2. A report header from nothing

Build a one-row report header: the literal text `RetailIQ Catalogue Export`, today's date, and the number 1 as a version. No table is involved.

<details>
<summary>Solution</summary>

```sql
SELECT 'RetailIQ Catalogue Export' AS report_name,
       CURRENT_DATE                AS generated_on,
       1                           AS version
```

**Returns:** 1 row

**Why it works.** A `SELECT` needs no `FROM`. Every value here is a literal or a function call, so the result is exactly one row. This is how you generate constants to union onto a real result set.

</details>

### Q3. Which countries do we bill?

Sales wants the distinct list of countries RetailIQ has ever billed an invoice to, alphabetically.

<details>
<summary>Solution</summary>

```sql
SELECT DISTINCT BillingCountry AS country
FROM chinook.Invoice
ORDER BY country
```

**Returns:** 24 rows

**Why it works.** `DISTINCT` de-duplicates the whole selected row, not just one column - a habit worth forming before you add a second column and wonder why duplicates reappear.

</details>

### Q4. Track length in minutes

Track lengths are stored in milliseconds, which no one can read. Return the track name and its length as **whole** minutes plus leftover whole seconds, for the 10 longest tracks.

<details>
<summary>Solution</summary>

```sql
SELECT Name                          AS track,
       Milliseconds // 60000         AS minutes,
       (Milliseconds % 60000) // 1000 AS seconds
FROM chinook.Track
ORDER BY Milliseconds DESC
LIMIT 10
```

**Returns:** 10 rows

**Why it works.** Note `//`, not `/`. In DuckDB `/` is *true* division - `300000 / 60000` gives `5.0`, and `7 / 2` gives `3.5`, so `/` would have produced fractional minutes and failed the question. `//` is floor division. PostgreSQL does the opposite: `/` on two integers truncates. The same query genuinely returns different answers on the two engines, which makes this one of the easiest ways to ship a wrong number when porting SQL.

</details>

## Module 02 — Numeric, text and boolean types

### Q5. Flagging long tracks

Mark each track as long or not: return the name and a true/false column `is_long` that is true when the track runs over five minutes. Show 10 rows that are long.

<details>
<summary>Solution</summary>

```sql
SELECT Name                       AS track,
       Milliseconds > 300000      AS is_long
FROM chinook.Track
WHERE Milliseconds > 300000
LIMIT 10
```

**Returns:** 10 rows

**Why it works.** A comparison *is* a boolean expression - you can select it directly, not just use it in `WHERE`. Five minutes is 300,000 ms. Writing `300000` inline is fine here; in production name it, because a bare number in six months means nothing.

</details>

### Q6. Why money is never a float

`chinook.Track.UnitPrice` is stored as `DOUBLE`. Sum it two ways - as the raw double, and cast to `DECIMAL(10,2)` first - and show that they differ.

<details>
<summary>Solution</summary>

```sql
SELECT SUM(UnitPrice)                        AS as_double,
       SUM(CAST(UnitPrice AS DECIMAL(10,2)))   AS as_decimal,
       SUM(UnitPrice) - SUM(CAST(UnitPrice AS DECIMAL(10,2))) AS drift
FROM chinook.Track
```

**Returns:** 1 row

**Why it works.** Binary floating point cannot represent 0.99 exactly, so summing thousands of them accumulates error. The drift is tiny here but it is not zero - and on a real ledger 'tiny but not zero' is a reconciliation failure. Money belongs in `DECIMAL`/`NUMERIC`, always.

</details>

### Q7. The longest product name

The catalogue UI truncates long names. Find the 5 longest track names and their character length.

<details>
<summary>Solution</summary>

```sql
SELECT Name              AS track,
       LENGTH(Name)      AS chars
FROM chinook.Track
ORDER BY chars DESC
LIMIT 5
```

**Returns:** 5 rows

**Why it works.** `LENGTH` counts characters, not bytes - `OCTET_LENGTH` counts bytes. They differ the moment a name contains an accented or non-Latin character, which is exactly when a UI truncation bug appears.

</details>

## Module 03 — Date, time and interval types

### Q8. Sales by calendar year

Finance wants invoice counts per year. Return the year and how many invoices were raised, newest year first.

<details>
<summary>Solution</summary>

```sql
SELECT EXTRACT(year FROM InvoiceDate) AS invoice_year,
       COUNT(*)                        AS invoices
FROM chinook.Invoice
GROUP BY invoice_year
ORDER BY invoice_year DESC
```

**Returns:** 5 rows

**Why it works.** `EXTRACT` pulls one field out of a timestamp. Note it returns a number, not a date - so `invoice_year` sorts numerically, which is what you want. Grouping by the alias works in DuckDB; in stricter engines you repeat the expression or use the ordinal.

</details>

### Q9. The month after a launch

A campaign launched on 2021-01-01. Return every invoice raised in the 30 days from that date inclusive, with its date and total, oldest first. (Check the data's real date range first — guessing a window and getting zero rows back is a mistake worth making once.)

<details>
<summary>Solution</summary>

```sql
SELECT InvoiceId, InvoiceDate, Total
FROM chinook.Invoice
WHERE InvoiceDate >= DATE '2021-01-01'
  AND InvoiceDate <  DATE '2021-01-01' + INTERVAL 30 DAY
ORDER BY InvoiceDate
```

**Returns:** 6 rows

**Why it works.** `>= start AND < end` is the correct half-open range for timestamps. `BETWEEN` would include the whole final day only if the column were a date; because it is a timestamp, `BETWEEN` silently drops everything after midnight on the last day. This is one of the most common real-world date bugs.

</details>

### Q10. Staff tenure

HR wants length of service. From `chinook.Employee`, return each employee's name, hire date, and completed years of service as at 2010-01-01, longest-serving first.

<details>
<summary>Solution</summary>

```sql
SELECT FirstName || ' ' || LastName AS employee,
       HireDate,
       DATE_DIFF('year', HireDate, DATE '2010-01-01') AS years_service
FROM chinook.Employee
ORDER BY years_service DESC, employee
```

**Returns:** 8 rows

**Why it works.** `DATE_DIFF` with a unit counts *boundaries crossed*, not elapsed time - someone hired on 31 Dec counts a full year on 1 Jan. If you need true elapsed years, subtract and divide, or compare month/day explicitly. Know which one your business means.

</details>

## Module 04 — Casting, coercion and TRY_CAST

### Q11. Summing a number that is stored as text

`raw.online_retail.Quantity` arrived as text. Return the total quantity sold across the whole file as a proper number.

<details>
<summary>Solution</summary>

```sql
SELECT SUM(CAST(Quantity AS INTEGER)) AS total_quantity
FROM raw.online_retail
```

**Returns:** 1 row

**Why it works.** The loader deliberately left every CSV column as `VARCHAR` so the defects stay visible. `SUM` on text fails outright, so the cast is mandatory. It works here only because every value happens to be castable - the next question is what to do when that is not true.

</details>

### Q12. Finding the values that will not cast

Before trusting `CustomerID` as a number, count how many rows would fail a numeric cast, and show five offending values.

<details>
<summary>Solution</summary>

```sql
SELECT COUNT(*) FILTER (WHERE TRY_CAST(CustomerID AS INTEGER) IS NULL) AS uncastable,
       COUNT(*)                                                          AS total
FROM raw.online_retail
```

Then, to see the offending values:

```sql
SELECT DISTINCT CustomerID
FROM raw.online_retail
WHERE TRY_CAST(CustomerID AS INTEGER) IS NULL
LIMIT 5
```

**Returns:** 1 row

**Why it works.** `TRY_CAST` returns NULL instead of raising, which turns 'does this cast?' into a countable question. That is the whole technique: never cast a dirty column without first counting the failures. Note the failures here are blank customer IDs, not junk - a different problem needing a different fix.

</details>

### Q13. Superstore revenue, from text

`raw.superstore_orders.Sales` is text. Return total sales rounded to 2 decimals, and the order count. Mind the column names - they contain spaces.

<details>
<summary>Solution</summary>

```sql
SELECT COUNT(*)                                        AS orders,
       ROUND(SUM(CAST(Sales AS DOUBLE)), 2)             AS total_sales
FROM raw.superstore_orders
```

**Returns:** 1 row

**Why it works.** Columns named `Order Date` or `Row ID` must be double-quoted to be referenced at all. This is why loaders usually rename columns to snake_case on the way in - every downstream query otherwise carries the quoting burden forever.

</details>

### Q14. Parsing a US date written as text

`raw.hr_employees.DateofHire` is text in `M/D/YYYY` form, e.g. `7/5/2011`. Return the employee name and hire date as a real date, earliest first, for the 10 earliest hires.

<details>
<summary>Solution</summary>

```sql
SELECT Employee_Name                          AS employee,
       STRPTIME(DateofHire, '%-m/%-d/%Y')::DATE AS hire_date
FROM raw.hr_employees
WHERE DateofHire IS NOT NULL AND DateofHire <> ''
ORDER BY hire_date
LIMIT 10
```

**Returns:** 10 rows

**Why it works.** `STRPTIME` needs the *exact* pattern. `%-m` accepts a non-padded month, so both `7/5/2011` and `07/05/2011` parse. Get this wrong and you do not get an error - you get NULLs, or worse, days and months silently swapped. `7/5/2011` is July 5th in US format and May 7th in UK format, and nothing in the data tells you which.

</details>

## Module 05 — NULL semantics, COALESCE, NULLIF

### Q15. The missing composers

Rights management needs to know how incomplete the composer data is. Return the total number of tracks, how many have no composer, and that as a percentage rounded to 1 decimal.

<details>
<summary>Solution</summary>

```sql
SELECT COUNT(*)                                          AS tracks,
       COUNT(*) - COUNT(Composer)                         AS missing_composer,
       ROUND(100.0 * (COUNT(*) - COUNT(Composer)) / COUNT(*), 1) AS pct_missing
FROM chinook.Track
```

**Returns:** 1 row

**Why it works.** `COUNT(*)` counts rows; `COUNT(col)` counts non-NULL values in that column. The difference between them *is* the null count - no `IS NULL` needed. Multiplying by `100.0` rather than `100` forces a decimal division; with integers you would get 0.

</details>

### Q16. A safe division

Return each Superstore order's profit margin as profit divided by sales. Some rows have zero sales - the query must not fail, and those rows should come back NULL rather than an error.

<details>
<summary>Solution</summary>

```sql
SELECT "Order ID"                                                    AS order_id,
       CAST(Sales AS DOUBLE)                                          AS sales,
       ROUND(CAST(Profit AS DOUBLE) / NULLIF(CAST(Sales AS DOUBLE), 0), 4) AS margin
FROM raw.superstore_orders
ORDER BY margin NULLS LAST
LIMIT 10
```

**Returns:** 10 rows

**Why it works.** `NULLIF(x, 0)` turns 0 into NULL, and dividing by NULL gives NULL instead of raising. This is the standard guard against divide-by-zero and it is one function, not a `CASE`. `NULLS LAST` keeps the unknowns out of the way when sorting.

</details>

### Q17. The NOT IN trap

HR wants the individual contributors: employees who manage nobody. Answer it with `NOT EXISTS`, then answer the identical question with `NOT IN`, and return both counts side by side. They will not agree. Work out which is right before reading on.

<details>
<summary>Solution</summary>

```sql
SELECT
  (SELECT COUNT(*) FROM chinook.Employee e
    WHERE NOT EXISTS (SELECT 1 FROM chinook.Employee m WHERE m.ReportsTo = e.EmployeeId))
        AS via_not_exists,
  (SELECT COUNT(*) FROM chinook.Employee e
    WHERE e.EmployeeId NOT IN (SELECT ReportsTo FROM chinook.Employee))
        AS via_not_in
```

**Returns:** 1 row

**Why it works.** `NOT EXISTS` returns 5 - the correct answer, out of 8 employees. `NOT IN` returns **0**, and it is wrong.

`chinook.Employee.ReportsTo` contains one NULL, because the boss reports to nobody. So the subquery yields a list like `(1, 2, 2, NULL, ...)`, and `x NOT IN (..., NULL)` can never be true: SQL cannot confirm `x <> NULL`, so the whole predicate evaluates to NULL, which is not true, so **every row is filtered out**.

There is no error and no warning - just a silently empty result. This is the single most expensive NULL bug in SQL. Use `NOT EXISTS`, or add `WHERE ReportsTo IS NOT NULL` to the subquery.

</details>

## Module 06 — String and numeric function library

### Q18. Splitting 'Last, First' names

`raw.hr_employees.Employee_Name` is stored as `"Adinolfi, Wilson  K"` - surname, comma, forename, and sometimes a double space before a middle initial. Return the original, the surname, and the forename cleanly separated, for 10 rows.

<details>
<summary>Solution</summary>

```sql
SELECT Employee_Name                                        AS original,
       TRIM(SPLIT_PART(Employee_Name, ',', 1))               AS surname,
       TRIM(REGEXP_REPLACE(SPLIT_PART(Employee_Name, ',', 2), '\s+', ' ', 'g')) AS forename
FROM raw.hr_employees
ORDER BY surname
LIMIT 10
```

**Returns:** 10 rows

**Why it works.** `SPLIT_PART` takes the nth piece around a delimiter - safer than hand-rolled `SUBSTRING` and `POSITION`. The `REGEXP_REPLACE` with `\s+` collapses any run of whitespace to one space, which is what fixes the double space. `TRIM` then removes the leading space left by the comma.

</details>

### Q19. Normalising messy product descriptions

`raw.online_retail.Description` has inconsistent casing and stray whitespace. Return the distinct cleaned description - trimmed, internal whitespace collapsed, upper-cased - for the 10 that appear most often, with their row counts.

<details>
<summary>Solution</summary>

```sql
SELECT UPPER(TRIM(REGEXP_REPLACE(Description, '\s+', ' ', 'g'))) AS clean_description,
       COUNT(*)                                                   AS rows
FROM raw.online_retail
WHERE Description IS NOT NULL
GROUP BY clean_description
ORDER BY rows DESC
LIMIT 10
```

**Returns:** 10 rows

**Why it works.** Cleaning *before* grouping is the whole point - group on the raw column and `" WHITE MUG "` and `"White Mug"` become two products. Order matters too: collapse whitespace, then trim, then case-fold. Doing this consistently is why the project keeps a shared normalisation expression rather than retyping it.

</details>

### Q20. Fare bands for the taxi data

Group the 2.9M taxi trips into $10 fare bands and count them. Return the band's lower bound and the trip count, cheapest band first, for fares between $0 and $100.

<details>
<summary>Solution</summary>

```sql
SELECT FLOOR(fare_amount / 10) * 10 AS band_low,
       COUNT(*)                     AS trips
FROM raw.taxi_trips
WHERE fare_amount >= 0 AND fare_amount < 100
GROUP BY band_low
ORDER BY band_low
```

**Returns:** 10 rows

**Why it works.** `FLOOR(x / w) * w` is the arithmetic way to bucket a continuous value into fixed-width bands - no `CASE` ladder, and it keeps working when the range changes. `WIDTH_BUCKET` does the same with explicit bounds when you need a fixed number of buckets instead of a fixed width.

</details>

---

## Coverage

| Module | Topic | Questions |
| --- | --- | ---: |
| `01` | SELECT, projection, aliases and literals | 4 |
| `02` | Numeric, text and boolean types | 3 |
| `03` | Date, time and interval types | 3 |
| `04` | Casting, coercion and TRY_CAST | 4 |
| `05` | NULL semantics, COALESCE, NULLIF | 3 |
| `06` | String and numeric function library | 3 |

**20 questions across 6 modules.**
