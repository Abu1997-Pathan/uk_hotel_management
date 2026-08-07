-- ============================================================================
-- UK Hotel Management — Section 13 "Practical Interview Tasks"
-- ============================================================================
-- All 8 numbered tasks from the handbook's Section 13, reproduced with
-- their model-answer SQL verbatim and run against the real dataset from
-- 02_data_insertion.sql. Every result below was captured from a live
-- MySQL 8.0.46 instance. "Each task connects only two tables" per the
-- handbook's own framing note, and every model answer below does exactly
-- that.
-- ============================================================================

USE uk_hotel_management;

-- ----------------------------------------------------------------------------
-- Task 1: Display every booking with the guest name and city.
-- ----------------------------------------------------------------------------
SELECT b.booking_id, g.guest_name, g.guest_city
FROM bookings AS b
INNER JOIN guest AS g ON b.guest_id = g.guest_id;
-- Actual result: 20 rows (one per booking). Oliver Smith (London) appears
-- three times, matching his three bookings in the dataset; Sophia Hall
-- and Grace Wood each appear exactly once.

-- ----------------------------------------------------------------------------
-- Task 2: Return bookings between GBP 300 and GBP 800 with the guest name,
-- highest amount first.
-- ----------------------------------------------------------------------------
SELECT g.guest_name, b.booking_id, b.booking_amount
FROM guest AS g
INNER JOIN bookings AS b ON g.guest_id = b.guest_id
WHERE b.booking_amount BETWEEN 300 AND 800
ORDER BY b.booking_amount DESC;
-- Actual result: 9 rows, from Ava Evans (725.00) down to Emily Walker
-- (360.00). George Taylor appears twice (594.00 and 560.00) because two
-- of his three bookings fall in this range.

-- ----------------------------------------------------------------------------
-- Task 3: Show all guests, including those without a booking.
-- ----------------------------------------------------------------------------
SELECT g.guest_id, g.guest_name, b.booking_id
FROM guest AS g
LEFT JOIN bookings AS b ON g.guest_id = b.guest_id;
-- Actual result: 23 rows for 15 guests -- guests with multiple bookings
-- appear multiple times, and the 3 guests with no booking at all (Jacob
-- White, Charlie Green, Leo Baker) each appear once with booking_id NULL.

-- ----------------------------------------------------------------------------
-- Task 4: Find only guests without a booking.
-- ----------------------------------------------------------------------------
SELECT g.guest_id, g.guest_name
FROM guest AS g
LEFT JOIN bookings AS b ON g.guest_id = b.guest_id
WHERE b.booking_id IS NULL;
-- Actual result (3 rows):
-- guest_id | guest_name
-- 11       | Jacob White
-- 13       | Charlie Green
-- 15       | Leo Baker

-- ----------------------------------------------------------------------------
-- Task 5: Show the five highest booking amounts with room type.
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- Task 6: Show every room, attaching only bookings worth at least GBP 500.
-- ----------------------------------------------------------------------------
SELECT r.room_id, r.room_type, b.booking_id, b.booking_amount
FROM room AS r
LEFT JOIN bookings AS b
  ON r.room_id = b.room_id
  AND b.booking_amount >= 500;
-- Actual result: 17 rows for 15 rooms. Rooms 9 (Family Room) and 11
-- (Suite) each appear twice because each has two qualifying bookings
-- (560.00 and 700.00 on room 9; 880.00 and 660.00 on room 11); room 5
-- (Double Room) appears once with its 594.00 booking; the remaining 11
-- rooms each appear once with booking_id NULL, because either they have
-- no booking at all or none of their bookings reach GBP 500. This is the
-- same ON-vs-WHERE discipline from 05_join_queries.sql Query 6b: the
-- GBP 500 filter sits in ON, so it decides which booking attaches, not
-- whether the room row survives.

-- ----------------------------------------------------------------------------
-- Task 7: Return booking and room details for Double Room or Twin Room.
-- ----------------------------------------------------------------------------
SELECT b.booking_id, r.room_id, r.room_type
FROM bookings AS b
INNER JOIN room AS r ON b.room_id = r.room_id
WHERE r.room_type IN ('Double Room', 'Twin Room');
-- Actual result: 11 rows -- 7 Double Room bookings (rooms 3, 4, 5, 14)
-- and 4 Twin Room bookings (rooms 6, 7, 8).

-- ----------------------------------------------------------------------------
-- Task 8: Generate every guest-room combination but show only the first
-- 20 in a stable order.
-- ----------------------------------------------------------------------------
SELECT g.guest_name, r.room_id, r.room_type
FROM guest AS g
CROSS JOIN room AS r
ORDER BY g.guest_id, r.room_id
LIMIT 20;
-- Actual result: the first 20 of the full 225-row CROSS JOIN (15 guests x
-- 15 rooms — see Query 4 in 05_join_queries.sql), all 15 rows for guest_id
-- 1 (Oliver Smith, across all 15 rooms) followed by the first 5 rows for
-- guest_id 2 (Amelia Jones, rooms 1-5). The ORDER BY on both join keys is
-- what makes "the first 20" a stable, reproducible slice rather than
-- whatever order the storage engine happens to produce.
