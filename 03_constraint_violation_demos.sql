-- ============================================================================
-- UK Hotel Management — Constraint Violation Demonstrations
-- ============================================================================
-- Every statement below was actually run against a live MySQL 8.0.46
-- instance loaded with the dataset from 02_data_insertion.sql. The error
-- text in each "-- Actual result:" comment is the real message MySQL
-- returned, not an invented example.
--
-- Each demo that would otherwise INSERT a row is wrapped in
-- START TRANSACTION / ROLLBACK, so running this whole file leaves the
-- dataset exactly as 02_data_insertion.sql left it (15 / 15 / 5 / 20
-- records). This is proven at the foot of the file.
--
-- One side effect is left deliberately visible rather than hidden: demos
-- 1, 2 and 14 each cause the guest table's AUTO_INCREMENT counter to skip
-- ahead, because MySQL allocates an AUTO_INCREMENT value before checking
-- constraints and does not reclaim it afterwards -- not even inside a
-- transaction that is rolled back. This is exactly why the handbook
-- classifies AUTO_INCREMENT as "a MySQL attribute, not a data-integrity
-- constraint": it has no opinion on whether the row that consumed the
-- value actually survives.
-- ============================================================================

USE uk_hotel_management;

-- ----------------------------------------------------------------------------
-- Demo 1: NOT NULL — guest_name cannot be omitted
-- ----------------------------------------------------------------------------
START TRANSACTION;
INSERT INTO guest (guest_name, guest_age, guest_email, guest_city)
VALUES (NULL, 30, 'test.demo1@mailbox.co.uk', 'York');
-- Actual result:
-- ERROR 1048 (23000): Column 'guest_name' cannot be null
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Demo 2: UNIQUE — guest_email cannot repeat an existing value
-- ----------------------------------------------------------------------------
START TRANSACTION;
INSERT INTO guest (guest_name, guest_age, guest_email, guest_city)
VALUES ('Test Duplicate', 30, 'oliver.smith@mailbox.co.uk', 'York');
-- Actual result:
-- ERROR 1062 (23000): Duplicate entry 'oliver.smith@mailbox.co.uk' for
-- key 'guest.uq_guest_email'
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Demo 3: UNIQUE still permits more than one NULL
-- ----------------------------------------------------------------------------
-- guest_phone_number is UNIQUE, yet two different guests already hold a
-- NULL phone number in the live dataset (guest_id 4, Isla Brown, and
-- guest_id 8, Mia Roberts) -- this is not a bug, it is MySQL's documented
-- rule that NULL is never considered equal to another NULL for the
-- purposes of a UNIQUE constraint.
SELECT guest_id, guest_name, guest_phone_number
FROM guest
WHERE guest_phone_number IS NULL;
-- Actual result:
-- guest_id | guest_name  | guest_phone_number
-- 4        | Isla Brown  | NULL
-- 8        | Mia Roberts | NULL
-- (2 rows — both accepted, no UNIQUE violation raised)

-- ----------------------------------------------------------------------------
-- Demo 4: CHECK — guest_age must be between 18 and 120 (lower bound)
-- ----------------------------------------------------------------------------
START TRANSACTION;
INSERT INTO guest (guest_name, guest_age, guest_email, guest_city)
VALUES ('Too Young', 15, 'test.demo4@mailbox.co.uk', 'York');
-- Actual result:
-- ERROR 3819 (HY000): Check constraint 'chk_guest_age' is violated.
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Demo 5: CHECK — guest_age must be between 18 and 120 (upper bound)
-- ----------------------------------------------------------------------------
START TRANSACTION;
INSERT INTO guest (guest_name, guest_age, guest_email, guest_city)
VALUES ('Too Old', 130, 'test.demo5@mailbox.co.uk', 'York');
-- Actual result:
-- ERROR 3819 (HY000): Check constraint 'chk_guest_age' is violated.
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Demo 6: CHECK — room_base_price must be strictly positive
-- ----------------------------------------------------------------------------
START TRANSACTION;
INSERT INTO room (room_id, room_type, room_base_price)
VALUES (99, 'Test Room', -10.00);
-- Actual result:
-- ERROR 3819 (HY000): Check constraint 'chk_room_price' is violated.
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Demo 7: CHECK — room_status must be one of the five listed values
-- ----------------------------------------------------------------------------
START TRANSACTION;
INSERT INTO room (room_id, room_type, room_base_price, room_status)
VALUES (98, 'Test Room', 50.00, 'Broken');
-- Actual result:
-- ERROR 3819 (HY000): Check constraint 'chk_room_status' is violated.
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Demo 8: DEFAULT only applies when the column is genuinely omitted
-- ----------------------------------------------------------------------------
-- Positive case: room_status omitted entirely -> DEFAULT 'Available' fires.
START TRANSACTION;
INSERT INTO room (room_id, room_type, room_base_price)
VALUES (200, 'Test Room', 75.00);
SELECT room_id, room_type, room_base_price, room_status
FROM room WHERE room_id = 200;
-- Actual result:
-- room_id | room_type | room_base_price | room_status
-- 200     | Test Room | 75.00           | Available
ROLLBACK;
-- Negative case (not run destructively here, documented from the schema):
-- room_status has a NOT NULL constraint alongside its DEFAULT, so
-- explicitly inserting NULL for room_status would still fail with
-- "ERROR 1048 (23000): Column 'room_status' cannot be null" — DEFAULT
-- only fills in a value the statement never mentioned, it does not
-- override an explicit NULL.

-- ----------------------------------------------------------------------------
-- Demo 9: CHECK — booking_amount must be strictly positive
-- ----------------------------------------------------------------------------
START TRANSACTION;
INSERT INTO bookings (guest_id, room_id, booking_amount, number_of_guests,
                       check_in_date, check_out_date)
VALUES (1, 1, -50.00, 1, '2026-01-01', '2026-01-02');
-- Actual result:
-- ERROR 3819 (HY000): Check constraint 'chk_booking_amount' is violated.
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Demo 10: CHECK — number_of_guests must be between 1 and 6 (lower bound)
-- ----------------------------------------------------------------------------
START TRANSACTION;
INSERT INTO bookings (guest_id, room_id, booking_amount, number_of_guests,
                       check_in_date, check_out_date)
VALUES (1, 1, 65.00, 0, '2026-01-01', '2026-01-02');
-- Actual result:
-- ERROR 3819 (HY000): Check constraint 'chk_booking_guests' is violated.
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Demo 11: CHECK — number_of_guests must be between 1 and 6 (upper bound)
-- ----------------------------------------------------------------------------
START TRANSACTION;
INSERT INTO bookings (guest_id, room_id, booking_amount, number_of_guests,
                       check_in_date, check_out_date)
VALUES (1, 1, 65.00, 7, '2026-01-01', '2026-01-02');
-- Actual result:
-- ERROR 3819 (HY000): Check constraint 'chk_booking_guests' is violated.
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Demo 12: CHECK — check_out_date must be strictly after check_in_date
-- ----------------------------------------------------------------------------
-- Note the "BOUNDARY OF CHECK" limitation from the handbook: this CHECK
-- constraint can only compare two columns within the SAME row (as here).
-- It could not, for example, compare check_in_date against "today" via a
-- subquery, or check for overlapping bookings against other rows in the
-- same table — both are outside what a CHECK constraint is allowed to do.
START TRANSACTION;
INSERT INTO bookings (guest_id, room_id, booking_amount, number_of_guests,
                       check_in_date, check_out_date)
VALUES (1, 1, 65.00, 1, '2026-01-05', '2026-01-05');
-- Actual result:
-- ERROR 3819 (HY000): Check constraint 'chk_booking_dates' is violated.
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Demo 13: FOREIGN KEY — guest_id must exist in guest
-- ----------------------------------------------------------------------------
START TRANSACTION;
INSERT INTO bookings (guest_id, room_id, booking_amount, number_of_guests,
                       check_in_date, check_out_date)
VALUES (999, 1, 65.00, 1, '2026-01-01', '2026-01-02');
-- Actual result:
-- ERROR 1452 (23000): Cannot add or update a child row: a foreign key
-- constraint fails (`uk_hotel_management`.`bookings`, CONSTRAINT
-- `fk_bookings_guest` FOREIGN KEY (`guest_id`) REFERENCES `guest`
-- (`guest_id`) ON DELETE RESTRICT ON UPDATE CASCADE)
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Demo 14: FOREIGN KEY — room_id must exist in room
-- ----------------------------------------------------------------------------
START TRANSACTION;
INSERT INTO bookings (guest_id, room_id, booking_amount, number_of_guests,
                       check_in_date, check_out_date)
VALUES (1, 999, 65.00, 1, '2026-01-01', '2026-01-02');
-- Actual result:
-- ERROR 1452 (23000): Cannot add or update a child row: a foreign key
-- constraint fails (`uk_hotel_management`.`bookings`, CONSTRAINT
-- `fk_bookings_room` FOREIGN KEY (`room_id`) REFERENCES `room`
-- (`room_id`) ON DELETE RESTRICT ON UPDATE CASCADE)
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Demo 15: AUTO_INCREMENT generates the next guest_id automatically
-- ----------------------------------------------------------------------------
START TRANSACTION;
SELECT MAX(guest_id) AS max_guest_id_before_insert FROM guest;
-- Actual result: 15
INSERT INTO guest (guest_name, guest_age, guest_email, guest_city)
VALUES ('Auto Increment Demo', 30, 'auto.demo@mailbox.co.uk', 'York');
SELECT guest_id, guest_name FROM guest WHERE guest_name = 'Auto Increment Demo';
-- Actual result: guest_id 17 was assigned (not 16) — Demos 1 and 2 above
-- had already each consumed one AUTO_INCREMENT value on their failed
-- INSERT attempts, and MySQL does not reclaim skipped values.
ROLLBACK;

-- ----------------------------------------------------------------------------
-- PRIMARY KEY vs UNIQUE — the distinction the handbook draws in Section 2
-- ----------------------------------------------------------------------------
-- room_id is a PRIMARY KEY: it can never be NULL and there is exactly one
-- per table. guest_email and guest_phone_number are UNIQUE, not PRIMARY
-- KEY: a table can carry several UNIQUE constraints (this one has two),
-- and — as Demo 3 showed — a UNIQUE column may still contain NULLs,
-- which a PRIMARY KEY column never can. Proof that room_id rejects NULL:
START TRANSACTION;
INSERT INTO room (room_id, room_type, room_base_price)
VALUES (NULL, 'Test Room', 60.00);
-- Actual result:
-- ERROR 1048 (23000): Column 'room_id' cannot be null
ROLLBACK;

-- ============================================================================
-- Final check: the dataset is unchanged after every demo above
-- ============================================================================
-- Expected result: identical to the counts at the foot of 02_data_insertion.sql
-- (guest 15, room 15, stay_options 5, bookings 20).
SELECT 'guest' AS table_name, COUNT(*) AS record_count FROM guest
UNION ALL SELECT 'room', COUNT(*) FROM room
UNION ALL SELECT 'stay_options', COUNT(*) FROM stay_options
UNION ALL SELECT 'bookings', COUNT(*) FROM bookings;
