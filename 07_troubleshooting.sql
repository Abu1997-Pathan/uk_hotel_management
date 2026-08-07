-- ============================================================================
-- UK Hotel Management — Troubleshooting Patterns (Section 10)
-- ============================================================================
-- Every statement below was run against a live MySQL 8.0.46 instance
-- loaded with the dataset from 02_data_insertion.sql. Actual output/error
-- text is captured verbatim in the comments.
-- ============================================================================

USE uk_hotel_management;

-- ----------------------------------------------------------------------------
-- 1. Ambiguous column name error
-- ----------------------------------------------------------------------------
-- Both guest and bookings have a column named guest_id, so selecting the
-- bare column name once the two tables are joined is genuinely ambiguous
-- to MySQL — it does not guess which table you meant.
SELECT guest_id FROM guest g INNER JOIN bookings b ON g.guest_id = b.guest_id;
-- Actual result:
-- ERROR 1052 (23000): Column 'guest_id' in field list is ambiguous
--
-- Resolution: qualify the column with its table alias.
SELECT g.guest_id FROM guest g INNER JOIN bookings b ON g.guest_id = b.guest_id
LIMIT 5;
-- Actual result: resolves cleanly, returns 5 rows (4, 8, 1, 1, 1 in this
-- run — with no ORDER BY the exact row order is whatever the query
-- planner produces and is not guaranteed to repeat, but guest_id 1
-- (Oliver Smith) appearing more than once here is expected, since he has
-- three bookings — see item 2 below).

-- ----------------------------------------------------------------------------
-- 2. "Duplicate rows" that are not a bug — diagnosing the real cause
-- ----------------------------------------------------------------------------
-- A common support ticket: "joining guest to bookings is duplicating my
-- guest rows". Here is exactly that symptom for guest_id 1 (Oliver Smith):
SELECT g.guest_id, g.guest_name, b.booking_id
FROM guest AS g
INNER JOIN bookings AS b ON g.guest_id = b.guest_id
WHERE g.guest_id = 1;
-- Actual result: 3 rows, all "Oliver Smith", differing only by
-- booking_id (1, 2, 14).
--
-- Diagnosis query: use GROUP BY / HAVING to confirm this is a genuine
-- one-to-many relationship (one guest, several bookings) rather than a
-- data-quality problem (e.g. the same booking inserted twice).
SELECT g.guest_id, g.guest_name, COUNT(*) AS booking_count
FROM guest AS g
INNER JOIN bookings AS b ON g.guest_id = b.guest_id
GROUP BY g.guest_id, g.guest_name
HAVING COUNT(*) > 1
ORDER BY booking_count DESC, g.guest_id;
-- Actual result (7 rows — every guest who has booked more than once):
-- guest_id | guest_name    | booking_count
-- 1        | Oliver Smith  | 3
-- 2        | Amelia Jones  | 2
-- 3        | George Taylor | 2
-- 5        | Harry Wilson  | 2
-- 6        | Ava Evans     | 2
-- 9        | Noah Johnson  | 2
-- 10       | Emily Walker  | 2
-- Every count here is explained by a real, distinct booking_id per row —
-- this confirms the "duplication" is Oliver Smith's three genuine
-- bookings, not the same row appearing three times by mistake.

-- ----------------------------------------------------------------------------
-- 3. Why DISTINCT is not the fix (the handbook's explicit reflex warning)
-- ----------------------------------------------------------------------------
-- Reaching for DISTINCT here would make the "problem" disappear without
-- explaining it -- and would silently throw away real booking history.
SELECT DISTINCT g.guest_id, g.guest_name
FROM guest AS g
INNER JOIN bookings AS b ON g.guest_id = b.guest_id
WHERE g.guest_id = 1;
-- Actual result: exactly 1 row, "Oliver Smith". Technically this query
-- now "looks right" -- but it also silently deletes the information that
-- Oliver Smith has three separate bookings, which is precisely the data
-- a hotel system exists to keep track of. If a genuine duplicate-booking
-- data-entry error existed instead, DISTINCT would hide that too. The
-- GROUP BY/HAVING query in item 2 is the correct diagnostic; DISTINCT is
-- not a substitute for understanding the relationship.

-- ----------------------------------------------------------------------------
-- 4. Reading a query plan with EXPLAIN
-- ----------------------------------------------------------------------------
EXPLAIN SELECT b.booking_id, g.guest_name, r.room_type
FROM bookings AS b
INNER JOIN guest AS g ON b.guest_id = g.guest_id
INNER JOIN room AS r ON b.room_id = r.room_id
WHERE b.booking_amount >= 500;
-- Actual result (3 rows, one per table in the plan):
-- table | type   | key     | ref                              | rows | Extra
-- b     | ALL    | NULL    | NULL                              | ~21  | Using where
-- g     | eq_ref | PRIMARY | uk_hotel_management.b.guest_id    | 1    | NULL
-- r     | eq_ref | PRIMARY | uk_hotel_management.b.room_id     | 1    | NULL
--
-- Reading this: bookings (b) is scanned in full ("type: ALL", no index
-- used, because this small table has no index on booking_amount), while
-- guest and room are both looked up by primary key per matching row
-- ("type: eq_ref", the fastest possible join type). The "rows" column is
-- an estimate, not an exact count -- on a table this small (20 real rows)
-- InnoDB's statistics can legitimately estimate a nearby number like 21
-- rather than the literal row count; that is expected behaviour on small
-- tables, not evidence of a data problem. On a hotel database with
-- thousands of bookings, this same EXPLAIN output would be the first
-- place to check whether an index on booking_amount (or on the foreign
-- keys) would help.
