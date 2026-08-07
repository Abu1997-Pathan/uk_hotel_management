# UK Hotel Management — MySQL Constraints and Joins

A worked, fully-verified implementation of the schema and query patterns
from the *MySQL Constraints and Joins — UK Hotel Management Handbook*: a
four-table hotel booking database with every constraint type the handbook
covers, live-tested constraint-violation demonstrations, referential
integrity proof, the full set of INNER/LEFT/RIGHT/CROSS join patterns, and
model answers to all 8 numbered "practical interview tasks" from the
handbook's Section 13.

Every SQL statement in this repository was run against a real MySQL 8.0.46
instance. Every result quoted in a comment is the actual output that
instance returned, not an invented example.

## Why this project exists

The handbook itself is reference material: it explains each constraint and
join type in isolation with small illustrative examples. This project
takes that reference material and builds it out into one coherent,
runnable database with a single realistic dataset, so every technique in
the handbook can be seen working together against the same 55 rows of
data rather than in disconnected snippets.

## Schema

Reproduced verbatim from the handbook's Section 2.12 "Recommended complete
schema" — see [`01_schema_creation.sql`](01_schema_creation.sql) and
[`database_diagram.md`](database_diagram.md) for the full ER diagram.

| Table          | Purpose                                     | Key constraints |
|----------------|----------------------------------------------|------------------|
| `guest`        | People who stay at the hotel                  | `guest_email` and `guest_phone_number` each `UNIQUE`; `guest_age` `CHECK`ed between 18 and 120 |
| `room`         | Physical rooms available to book              | `room_base_price` `CHECK`ed positive; `room_status` `CHECK`ed against a fixed list; `DEFAULT 'Available'` |
| `bookings`     | One row per stay                              | Foreign keys to `guest` and `room` (`ON UPDATE CASCADE ON DELETE RESTRICT`); `CHECK` constraints on amount, guest count, and date ordering |
| `stay_options` | Standalone 1-5 night lookup table              | Used only for the `CROSS JOIN` pricing-grid demonstration |

## Dataset

15 guests, 15 rooms, 5 stay options, and 20 bookings — 55 records in total.
Full details and the live-captured record counts are in
[`record_count_evidence.md`](record_count_evidence.md).

The 15-guest / 15-room sizing is not arbitrary: the handbook's own Section
8.2 states "With 15 guests and 15 rooms, the query returns 15x15=225
rows" for the guest-room `CROSS JOIN`. This dataset was sized to reproduce
that exact figure.

The dataset also deliberately includes:
- 3 guests with no booking at all, and 3 rooms with no booking at all — so
  every `LEFT JOIN` / "unmatched row" query in this project has a real,
  non-empty result to show, not a hypothetical one.
- 2 guests with no phone number on file (`NULL`), demonstrating that a
  `UNIQUE` column can hold more than one `NULL` in MySQL.
- Every `booking_amount` equal to exactly `nights x room_base_price` for
  the room actually booked, so every figure in every query result is
  independently checkable by hand.

## Files

| File | Contents |
|------|----------|
| [`01_schema_creation.sql`](01_schema_creation.sql) | `CREATE DATABASE` / `CREATE TABLE` with every constraint, verbatim from Section 2.12 |
| [`02_data_insertion.sql`](02_data_insertion.sql) | The 55-record dataset, plus a self-check query proving every booking amount is correct |
| [`03_constraint_violation_demos.sql`](03_constraint_violation_demos.sql) | Every `NOT NULL`, `UNIQUE`, `CHECK`, `FOREIGN KEY`, `DEFAULT` and `AUTO_INCREMENT` rule deliberately tested, with the real MySQL error text captured |
| [`04_referential_integrity_demos.sql`](04_referential_integrity_demos.sql) | `ON DELETE RESTRICT` and `ON UPDATE CASCADE` proven live, insert/delete ordering, and the orphan-record diagnostic query |
| [`05_join_queries.sql`](05_join_queries.sql) | Every `INNER` / `LEFT` / `RIGHT` / `CROSS JOIN` pattern from Sections 4-9, including the `ON`-vs-`WHERE` outer-join pitfall and the deterministic Top-N pattern |
| [`06_interview_tasks.sql`](06_interview_tasks.sql) | Model answers to all 8 numbered tasks in Section 13, run against the real dataset |
| [`07_troubleshooting.sql`](07_troubleshooting.sql) | The ambiguous-column-name error, the duplicate-row diagnostic (and why `DISTINCT` is not the fix), and an `EXPLAIN` walkthrough |
| [`database_diagram.md`](database_diagram.md) / `.png` / `.pdf` | Text and Mermaid ER diagrams of the schema |
| [`record_count_evidence.md`](record_count_evidence.md) | Live-captured record counts, before and after the constraint/integrity demo files run |

## Running it yourself

Requires MySQL 8.0+ (constraint-name-in-error-message behaviour and
`CHECK` constraint enforcement both depend on 8.0's InnoDB implementation).

```bash
mysql -u root < 01_schema_creation.sql
mysql -u root < 02_data_insertion.sql
mysql -u root --force uk_hotel_management < 03_constraint_violation_demos.sql
mysql -u root --force uk_hotel_management < 04_referential_integrity_demos.sql
mysql -u root uk_hotel_management < 05_join_queries.sql
mysql -u root uk_hotel_management < 06_interview_tasks.sql
mysql -u root --force uk_hotel_management < 07_troubleshooting.sql
```

`--force` is required for `03`, `04` and `07` because those files
deliberately trigger real constraint and integrity errors as
demonstrations — `--force` tells the `mysql` client to keep going past an
expected error rather than stop, exactly as intended. Every one of those
three files ends with a query confirming the dataset is unchanged
(15 guests, 15 rooms, 5 stay options, 20 bookings) once it finishes.

## Key techniques demonstrated

- Every constraint type: `NOT NULL`, `UNIQUE` (including the MySQL-specific
  rule that a `UNIQUE` column may hold multiple `NULL`s), `PRIMARY KEY`,
  `FOREIGN KEY`, `CHECK` (and its documented row-only scope — it cannot
  reference another table or use a subquery), `DEFAULT`, and
  `AUTO_INCREMENT`.
- Referential integrity in both directions: `ON DELETE RESTRICT` blocking a
  delete that would orphan a booking, and `ON UPDATE CASCADE` propagating
  a primary-key change automatically.
- All four join types, with an explicit demonstration of the single
  costliest join mistake: putting a filter on the optional side of a
  `LEFT JOIN` in `WHERE` instead of `ON`, which silently turns it into an
  `INNER JOIN`.
- The deterministic Top-N pattern (`ORDER BY ... , tie_breaker LIMIT n`).
- `CROSS JOIN` row-count discipline, including reproducing the handbook's
  own 225-row worked example.
- Diagnosing "duplicate rows" from a join correctly (via `GROUP BY` /
  `HAVING`) instead of reaching for `DISTINCT`, which hides the underlying
  relationship rather than explaining it.

## Source

*MySQL Constraints and Joins — UK Hotel Management Handbook*. Technical
behaviour verified against the MySQL 8.4 Reference Manual (per the
handbook's own Section 15 references).
