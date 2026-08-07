# Record-Count Evidence

Captured by running the counting query at the foot of `02_data_insertion.sql`
against a live MySQL 8.0.46 instance, immediately after loading the dataset
and before any later script (03-07) had run.

| Table          | Record count |
|----------------|-------------:|
| guest          | 15           |
| room           | 15           |
| stay_options   | 5            |
| bookings       | 20           |
| **TOTAL**      | **55**       |

## Why 15 guests and 15 rooms specifically

This is not an arbitrary round number: the handbook's own Section 8.2
worked example states "With 15 guests and 15 rooms, the query returns
15x15=225 rows" for the guest-room CROSS JOIN. Matching that exact figure
was a deliberate design choice, so that `05_join_queries.sql` Query 4 and
`06_interview_tasks.sql` Task 8 reproduce the handbook's own stated result
(225 total combinations) rather than an arbitrary different count.

## Stability check after 03_constraint_violation_demos.sql and
## 04_referential_integrity_demos.sql

Both of those files deliberately attempt inserts, updates and deletes that
either fail against a constraint or succeed inside a transaction that is
then rolled back. Running the whole project end-to-end in canonical order
(`01` -> `02` -> `03` -> `04` -> `05` -> `06` -> `07`) and re-counting every
table afterwards reproduces the exact same totals:

| Table          | Record count (after 03-07 have run) |
|----------------|-------------------------------------:|
| guest          | 15                                    |
| room           | 15                                    |
| stay_options   | 5                                     |
| bookings       | 20                                    |
| **TOTAL**      | **55**                                |

The one side effect that is *not* hidden is that the `guest` table's
AUTO_INCREMENT counter advances past 15 during `03_constraint_violation_demos.sql`,
because MySQL allocates an AUTO_INCREMENT value before checking constraints
and does not reclaim a value once a statement fails or is rolled back. This
is documented explicitly inside that file rather than treated as a bug --
it is exactly why the handbook classifies AUTO_INCREMENT as "a MySQL
attribute, not a data-integrity constraint": it guarantees uniqueness and
generation, never contiguity.
