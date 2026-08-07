-- ============================================================================
-- UK Hotel Management — Referential Integrity Demonstrations
-- ============================================================================
-- Covers Sections 3.3-3.5 of the handbook: the ON UPDATE / ON DELETE action
-- choice actually in effect, insert/delete ordering, and the orphan-record
-- diagnostic pattern. Every statement was run against a live MySQL 8.0.46
-- instance loaded with the dataset from 02_data_insertion.sql, and every
-- INSERT/UPDATE/DELETE below is wrapped in START TRANSACTION / ROLLBACK so
-- this file never changes the dataset (verified at the foot of the file).
-- ============================================================================

USE uk_hotel_management;

-- ----------------------------------------------------------------------------
-- 1. ON DELETE RESTRICT blocks deleting a guest that still has bookings
-- ----------------------------------------------------------------------------
-- guest_id 1 (Oliver Smith) has bookings on record (see 02_data_insertion.sql).
START TRANSACTION;
DELETE FROM guest WHERE guest_id = 1;
-- Actual result:
-- ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key
-- constraint fails (`uk_hotel_management`.`bookings`, CONSTRAINT
-- `fk_bookings_guest` FOREIGN KEY (`guest_id`) REFERENCES `guest`
-- (`guest_id`) ON DELETE RESTRICT ON UPDATE CASCADE)
ROLLBACK;

-- ----------------------------------------------------------------------------
-- 2. ON DELETE RESTRICT blocks deleting a room that still has bookings
-- ----------------------------------------------------------------------------
-- room_id 1 (Single Room) has bookings on record.
START TRANSACTION;
DELETE FROM room WHERE room_id = 1;
-- Actual result:
-- ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key
-- constraint fails (`uk_hotel_management`.`bookings`, CONSTRAINT
-- `fk_bookings_room` FOREIGN KEY (`room_id`) REFERENCES `room`
-- (`room_id`) ON DELETE RESTRICT ON UPDATE CASCADE)
ROLLBACK;

-- ----------------------------------------------------------------------------
-- 3. RESTRICT only blocks deletes that would actually orphan a row
-- ----------------------------------------------------------------------------
-- guest_id 11 (Jacob White) has no bookings at all (by design — see the
-- orphan diagnostic in section 6 below), so deleting that guest succeeds.
-- This proves RESTRICT is enforced per-row against real dependents, not a
-- blanket "never delete from guest" rule.
START TRANSACTION;
DELETE FROM guest WHERE guest_id = 11;
SELECT ROW_COUNT() AS rows_deleted;
-- Actual result: rows_deleted = 1 (no error — no dependent bookings exist)
ROLLBACK;

-- ----------------------------------------------------------------------------
-- 4. ON UPDATE CASCADE propagates a primary-key change to dependent bookings
-- ----------------------------------------------------------------------------
-- guest_id 5 (Harry Wilson) has two bookings on record.
START TRANSACTION;
SELECT guest_id, room_id FROM bookings WHERE guest_id = 5;
-- Actual result (before): (5, 11), (5, 2)
UPDATE guest SET guest_id = 500 WHERE guest_id = 5;
SELECT guest_id, room_id FROM bookings WHERE guest_id = 500;
-- Actual result (after): (500, 11), (500, 2) — both rows followed the
-- renumbered guest automatically, with no separate UPDATE statement
-- issued against bookings.
SELECT COUNT(*) AS rows_left_at_old_guest_id FROM bookings WHERE guest_id = 5;
-- Actual result: 0 — nothing was orphaned at the old id.
ROLLBACK;

-- ----------------------------------------------------------------------------
-- 5. Insert ordering: the parent row must exist before the child row
-- ----------------------------------------------------------------------------
-- Wrong order: try to insert a booking for a guest_id that has not been
-- created yet.
START TRANSACTION;
INSERT INTO bookings (guest_id, room_id, booking_amount, number_of_guests,
                       check_in_date, check_out_date)
VALUES (777, 1, 100.00, 1, '2026-01-01', '2026-01-02');
-- Actual result:
-- ERROR 1452 (23000): Cannot add or update a child row: a foreign key
-- constraint fails (`uk_hotel_management`.`bookings`, CONSTRAINT
-- `fk_bookings_guest` FOREIGN KEY (`guest_id`) REFERENCES `guest`
-- (`guest_id`) ON DELETE RESTRICT ON UPDATE CASCADE)
ROLLBACK;

-- Correct order: create the guest first, then the booking that references it.
START TRANSACTION;
INSERT INTO guest (guest_id, guest_name, guest_age, guest_email, guest_city)
VALUES (777, 'Order Demo Guest', 40, 'order.demo@mailbox.co.uk', 'York');
INSERT INTO bookings (guest_id, room_id, booking_amount, number_of_guests,
                       check_in_date, check_out_date)
VALUES (777, 1, 100.00, 1, '2026-01-01', '2026-01-02');
SELECT booking_id, guest_id, room_id FROM bookings WHERE guest_id = 777;
-- Actual result: exactly 1 row returned — the insert succeeded once the
-- parent row existed. (The booking_id value itself depends on how many
-- AUTO_INCREMENT values earlier demos in this project have already
-- consumed; the important, deterministic fact is that the row exists and
-- guest_id/room_id match what was inserted.)
ROLLBACK;

-- ----------------------------------------------------------------------------
-- 6. Orphan-record diagnostic (Section 3.5's LEFT JOIN + IS NULL pattern)
-- ----------------------------------------------------------------------------
-- This is not really about "orphans" in the corrupt-data sense here (the
-- foreign keys make true orphans impossible) — it is the same query
-- pattern used to find guests/rooms that are valid, intact rows but have
-- no matching booking at all, i.e. Section 13 interview tasks 3 and 4.
SELECT g.guest_id, g.guest_name, g.guest_city
FROM guest AS g
LEFT JOIN bookings AS b ON g.guest_id = b.guest_id
WHERE b.booking_id IS NULL
ORDER BY g.guest_id;
-- Actual result:
-- guest_id | guest_name    | guest_city
-- 11       | Jacob White   | Sheffield
-- 13       | Charlie Green | Leicester
-- 15       | Leo Baker     | Oxford

SELECT r.room_id, r.room_type, r.room_status
FROM room AS r
LEFT JOIN bookings AS b ON r.room_id = b.room_id
WHERE b.booking_id IS NULL
ORDER BY r.room_id;
-- Actual result:
-- room_id | room_type   | room_status
-- 12      | Suite       | Maintenance
-- 13      | Single Room | Available
-- 15      | Family Room | Available

-- ============================================================================
-- Final check: the dataset is unchanged after every demo above
-- ============================================================================
-- Expected result: guest 15, room 15, stay_options 5, bookings 20
-- (identical to the counts at the foot of 02_data_insertion.sql).
SELECT 'guest' AS table_name, COUNT(*) AS record_count FROM guest
UNION ALL SELECT 'room', COUNT(*) FROM room
UNION ALL SELECT 'stay_options', COUNT(*) FROM stay_options
UNION ALL SELECT 'bookings', COUNT(*) FROM bookings;
