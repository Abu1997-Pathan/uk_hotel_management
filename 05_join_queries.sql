-- ============================================================================
-- UK Hotel Management — Join Queries
-- ============================================================================
-- Every join pattern from handbook Sections 4-9, run against the real
-- dataset from 02_data_insertion.sql. Actual result sets are captured as
-- comments (verified against a live MySQL 8.0.46 instance) so the reader
-- can check the query logic against real numbers, not placeholders.
-- ============================================================================

USE uk_hotel_management;

-- ============================================================================
-- SECTION 4-5: INNER JOIN — matching rows only
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 1: every booking with guest and room detail (two INNER JOINs chained)
-- ----------------------------------------------------------------------------
SELECT b.booking_id, g.guest_name, g.guest_city, r.room_type, b.booking_amount
FROM bookings AS b
INNER JOIN guest AS g ON b.guest_id = g.guest_id
INNER JOIN room AS r ON b.room_id = r.room_id
ORDER BY b.booking_id;
-- Actual result: 20 rows — one per booking, because every booking has
-- exactly one guest and one room (both are NOT NULL foreign keys, so an
-- INNER JOIN can never silently drop a booking here).

-- ============================================================================
-- SECTION 6: LEFT JOIN — every row from the "required" side, matched or not
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 2: every guest, whether or not they have ever booked
-- ----------------------------------------------------------------------------
SELECT g.guest_id, g.guest_name, b.booking_id, b.booking_amount
FROM guest AS g
LEFT JOIN bookings AS b ON g.guest_id = b.guest_id
ORDER BY g.guest_id;
-- Actual result: 23 rows total (COUNT(*) = 23) for 15 guests — 12 guests
-- with at least one booking contribute 20 matched rows between them
-- (some, like Oliver Smith, contribute three), and the 3 guests with no
-- booking at all (Jacob White, Charlie Green, Leo Baker) each contribute
-- exactly one row with booking_id = NULL and booking_amount = NULL.
-- This is the handbook's "MEMORY RULE" in action: LEFT JOIN keeps every
-- left-table (guest) row no matter what.

-- ============================================================================
-- SECTION 7: RIGHT JOIN — every row from the named table, matched or not
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 3: every room, whether or not it has ever been booked
-- ----------------------------------------------------------------------------
-- Written from bookings RIGHT JOIN room, following the handbook's own
-- syntax-card convention (Section 14.3) of naming the table whose rows
-- must all survive on the right-hand side of RIGHT JOIN.
SELECT r.room_id, r.room_type, b.booking_id, b.booking_amount
FROM bookings AS b
RIGHT JOIN room AS r ON b.room_id = r.room_id
ORDER BY r.room_id;
-- Actual result: 23 rows for 15 rooms — 12 booked rooms contribute 20
-- matched rows between them, and the 3 unbooked rooms (12 Suite/
-- Maintenance, 13 Single Room, 15 Family Room) each contribute one row
-- with booking_id = NULL. Every LEFT JOIN in this file could equally be
-- rewritten as a RIGHT JOIN with the FROM/JOIN tables swapped — the two
-- are mirror images of each other, and this query is deliberately the
-- mirror image of Query 2.

-- ============================================================================
-- SECTION 8: CROSS JOIN — every possible combination
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 4: every guest-room combination (Section 8.2's worked example)
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS total_combinations FROM guest CROSS JOIN room;
-- Actual result: 225 — exactly 15 guests x 15 rooms, matching the
-- handbook's own row-count estimate in Section 8.2 word for word. This is
-- the row-count-estimation discipline the handbook calls out explicitly:
-- always know the expected row count of a CROSS JOIN before running it.

-- ----------------------------------------------------------------------------
-- Query 5: stay_options pricing grid (Section 8.3's CROSS JOIN pattern)
-- ----------------------------------------------------------------------------
-- Builds a full nights x price table for every room using the standalone
-- stay_options reference table — shown here for two representative rooms.
SELECT r.room_id, r.room_type, s.number_of_nights,
       r.room_base_price * s.number_of_nights AS total_price
FROM room AS r
CROSS JOIN stay_options AS s
WHERE r.room_id IN (1, 11)
ORDER BY r.room_id, s.number_of_nights;
-- Actual result (room 1, Single Room, GBP 65/night):
--   1 night = 65.00, 2 = 130.00, 3 = 195.00, 4 = 260.00, 5 = 325.00
-- Actual result (room 11, Suite, GBP 220/night):
--   1 night = 220.00, 2 = 440.00, 3 = 660.00, 4 = 880.00, 5 = 1100.00
-- Run without the WHERE filter, this CROSS JOIN would return
-- 15 rooms x 5 stay options = 75 rows in total.

-- ============================================================================
-- SECTION 9: the ON-vs-WHERE pitfall — the single most important join
-- lesson in the handbook, demonstrated with real, contrasting row counts
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 6a (WRONG): "every guest, plus any booking of GBP 500 or more"
-- ----------------------------------------------------------------------------
-- This LOOKS like a LEFT JOIN, but the WHERE clause filters on the
-- optional (right-hand) table's column — which silently discards every
-- NULL-extended unmatched row, making the query behave exactly like an
-- INNER JOIN.
SELECT g.guest_id, g.guest_name, b.booking_id, b.booking_amount
FROM guest AS g
LEFT JOIN bookings AS b ON g.guest_id = b.guest_id
WHERE b.booking_amount >= 500
ORDER BY g.guest_id;
-- Actual result: only 6 rows, covering just 5 distinct guests (1, 3, 5, 6,
-- 9). Every guest with no GBP 500+ booking — including all 3 guests with
-- no booking at all — has vanished from the result, even though the
-- query still says "LEFT JOIN".

-- ----------------------------------------------------------------------------
-- Query 6b (RIGHT): the same intent, condition moved into ON
-- ----------------------------------------------------------------------------
-- Moving the amount filter into the ON clause keeps it match-specific: it
-- decides which bookings are attached to a guest, but never decides
-- whether the guest row itself survives.
SELECT g.guest_id, g.guest_name, b.booking_id, b.booking_amount
FROM guest AS g
LEFT JOIN bookings AS b ON g.guest_id = b.guest_id AND b.booking_amount >= 500
ORDER BY g.guest_id;
-- Actual result: all 15 guests appear, exactly as a LEFT JOIN promises.
-- 5 of them are attached to a GBP 500+ booking; the other 10 (including
-- guests who do have bookings, just none reaching GBP 500, and the 3
-- guests with no booking at all) correctly show booking_id = NULL.
-- Six-row result vs fifteen-row result, from moving one condition three
-- words to the left — this is exactly the failure mode Section 9 warns
-- against.

-- ============================================================================
-- SECTION 9 (continued): deterministic Top-N with a tie-breaker
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 7: the five highest-value bookings, with room type
-- ----------------------------------------------------------------------------
-- booking_id is added as a second ORDER BY key purely as a tie-breaker.
-- In this dataset the top 5 amounts happen to be unique, so it changes
-- nothing about the output today — but without it, a future tie in
-- booking_amount would make LIMIT 5 return a different, unpredictable
-- set of rows on every run. Always add the tie-breaker before it is
-- needed, not after a bug report.
SELECT b.booking_id, r.room_type, b.booking_amount
FROM bookings AS b
INNER JOIN room AS r ON b.room_id = r.room_id
ORDER BY b.booking_amount DESC, b.booking_id ASC
LIMIT 5;
-- Actual result:
-- booking_id | room_type   | booking_amount
-- 6          | Suite       | 880.00
-- 8          | Family Room | 725.00
-- 14         | Family Room | 700.00
-- 18         | Suite       | 660.00
-- 16         | Double Room | 594.00

-- ============================================================================
-- Joins combined with WHERE / BETWEEN / IN / ORDER BY
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 8: bookings between GBP 300 and GBP 800, for Family Room or Suite
-- ----------------------------------------------------------------------------
SELECT g.guest_name, r.room_type, b.booking_amount, b.check_in_date
FROM bookings AS b
INNER JOIN guest AS g ON b.guest_id = g.guest_id
INNER JOIN room AS r ON b.room_id = r.room_id
WHERE b.booking_amount BETWEEN 300 AND 800
  AND r.room_type IN ('Family Room', 'Suite')
ORDER BY b.booking_amount DESC;
-- Actual result (4 rows, highest amount first):
-- Ava Evans     | Family Room | 725.00 | 2026-08-15
-- Oliver Smith  | Family Room | 700.00 | 2026-12-20
-- Noah Johnson  | Suite       | 660.00 | 2026-04-10
-- George Taylor | Family Room | 560.00 | 2026-04-01
