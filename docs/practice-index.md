# Practice questions — index

Thirteen sets of 20 questions, one per content folder — **260 questions** covering all 86 modules.

Each question is a standalone scenario against the real data, with a collapsible solution and an
explanation of why it works and what the trap was. Every solution is executed against
`data/retailiq.duckdb` before publication, and the row count printed under it is what it actually
returned.

Build the database first:

```powershell
pip install -r 00-setup/requirements.txt
python 00-setup/build_warehouse.py
```

## Why 260 and not 1,720

Twenty questions for each of the 86 modules would be about 1,720 questions — roughly 170 hours,
which is a set nobody finishes. One question per module is 86, which is too thin to build fluency:
you meet `LEFT JOIN` once and never again.

Twenty per *folder* lands at 260, around 25–30 hours of real work, and still touches all 86
modules. Narrow folders get depth they could not otherwise justify — `07-set-ops` has only three
modules, so 20 questions means seven angles on `EXCEPT` rather than one. Broad folders like
`06-windows` get two questions per module, which is enough to make the pattern stick.

Every question is labelled with the module it covers, so if one topic needs more, you know exactly
where the gap is.

## Sets

| Set | Folder | Modules | Questions | Status |
| --- | --- | --- | ---: | --- |
| 1 | [`01-foundations/questions.md`](../01-foundations/questions.md) | 01–06 | 20 | **Done** |
| 2 | `02-single-table/questions.md` | 07–13 | 20 | Pending |
| 3 | `03-joins/questions.md` | 14–21 | 20 | Pending |
| 4 | `04-aggregation/questions.md` | 22–27 | 20 | Pending |
| 5 | `05-subqueries-ctes/questions.md` | 28–34 | 20 | Pending |
| 6 | `06-windows/questions.md` | 35–44 | 20 | Pending |
| 7 | `07-set-ops/questions.md` | 45–47 | 20 | Pending |
| 8 | `08-dml/questions.md` | 48–53 | 20 | Pending |
| 9 | `ddl/questions.md` | 54–60 | 20 | Pending |
| 10 | `09-etl/questions.md` | 61–67 | 20 | Pending |
| 11 | `10-warehouse/questions.md` | 68–74 | 20 | Pending |
| 12 | `tests/questions.md` | 75–81 | 20 | Pending |
| 13 | `36-capstone-report/questions.md` | 82–86 | 20 | Pending |

**20 of 260 complete.**

## How this differs from the 20 project questions

Two different things, both useful:

- **[project-questions.md](project-questions.md)** — 20 large deliverables that build on each
  other. By Q20 you have a working warehouse. That is the portfolio piece.
- **These 260** — small, isolated drills. One concept, one scenario, one query. That is the
  fluency.

Do the drills for a folder, then the project question that uses them.
