-- ============================================================================
-- UK Hotel Management — Data Insertion
-- ============================================================================
-- Populates the schema created in 01_schema_creation.sql with a realistic,
-- internally-consistent dataset:
--   * 15 guests   (matches the handbook's own Section 8.2 worked example,
--                  "With 15 guests and 15 rooms, the query returns 225 rows")
--   * 15 rooms    (same reason)
--   * 5 stay_options rows (1-5 nights, exactly as given in Section 8.3)
--   * 20 bookings
--
-- Design notes (documented up front, not left implicit):
--   1. Every booking_amount is exactly number_of_nights x room_base_price
--      for the room actually booked, so the figures in every query result
--      are independently checkable by hand against room prices and dates.
--   2. Three guests (11, 13, 15) deliberately have no booking at all, and
--      three rooms (12, 13, 15) deliberately have no booking at all --
--      these gaps exist specifically so the LEFT JOIN / "unmatched row"
--      tasks in 05_join_queries.sql and 06_interview_tasks.sql have real,
--      non-empty results to show.
--   3. Two guests (guest_id 4 and 8) have no phone number on file
--      (guest_phone_number = NULL), demonstrating that a UNIQUE column can
--      hold more than one NULL in MySQL -- both are NULL, and the CREATE
--      TABLE in 01_schema_creation.sql still succeeded populating both.
--   4. room_status is a live operational snapshot, independent of booking
--      history -- a room can be "Cleaning" or "Maintenance" today and still
--      have past or future bookings on record. This is realistic hotel
--      behaviour, not a data error.
--
-- Verified against a live MySQL 8.0.46 instance.
-- ============================================================================

USE uk_hotel_management;

-- ----------------------------------------------------------------------------
-- guest (15 rows)
-- ----------------------------------------------------------------------------
INSERT INTO guest (guest_name, guest_age, guest_email, guest_phone_number, guest_city) VALUES
('Oliver Smith',   34, 'oliver.smith@mailbox.co.uk',  '07700 900001', 'London'),
('Amelia Jones',   29, 'amelia.jones@mailbox.co.uk',  '07700 900002', 'Manchester'),
('George Taylor',  45, 'george.taylor@mailbox.co.uk', '07700 900003', 'Birmingham'),
('Isla Brown',     52, 'isla.brown@mailbox.co.uk',    NULL,           'Leeds'),
('Harry Wilson',   38, 'harry.wilson@mailbox.co.uk',  '07700 900005', 'Bristol'),
('Ava Evans',      61, 'ava.evans@mailbox.co.uk',     '07700 900006', 'Liverpool'),
('Jack Thomas',    27, 'jack.thomas@mailbox.co.uk',   '07700 900007', 'Edinburgh'),
('Mia Roberts',    33, 'mia.roberts@mailbox.co.uk',   NULL,           'Glasgow'),
('Noah Johnson',   41, 'noah.johnson@mailbox.co.uk',  '07700 900009', 'Cardiff'),
('Emily Walker',   24, 'emily.walker@mailbox.co.uk',  '07700 900010', 'Newcastle'),
('Jacob White',    55, 'jacob.white@mailbox.co.uk',   '07700 900011', 'Sheffield'),
('Sophia Hall',    30, 'sophia.hall@mailbox.co.uk',   '07700 900012', 'Nottingham'),
('Charlie Green',  47, 'charlie.green@mailbox.co.uk', '07700 900013', 'Leicester'),
('Grace Wood',     36, 'grace.wood@mailbox.co.uk',    '07700 900014', 'Southampton'),
('Leo Baker',      22, 'leo.baker@mailbox.co.uk',     '07700 900015', 'Oxford');

-- ----------------------------------------------------------------------------
-- room (15 rows) -- room_id supplied explicitly (not AUTO_INCREMENT)
-- ----------------------------------------------------------------------------
INSERT INTO room (room_id, room_type, room_base_price, room_status) VALUES
(1,  'Single Room', 65.00,  'Available'),
(2,  'Single Room', 65.00,  'Occupied'),
(3,  'Double Room', 95.00,  'Available'),
(4,  'Double Room', 95.00,  'Reserved'),
(5,  'Double Room', 99.00,  'Available'),
(6,  'Twin Room',   90.00,  'Available'),
(7,  'Twin Room',   92.00,  'Cleaning'),
(8,  'Twin Room',   90.00,  'Available'),
(9,  'Family Room', 140.00, 'Available'),
(10, 'Family Room', 145.00, 'Occupied'),
(11, 'Suite',       220.00, 'Available'),
(12, 'Suite',       225.00, 'Maintenance'),
(13, 'Single Room', 68.00,  'Available'),
(14, 'Double Room', 97.00,  'Available'),
(15, 'Family Room', 150.00, 'Available');

-- ----------------------------------------------------------------------------
-- stay_options (5 rows) -- exactly as given in Section 8.3
-- ----------------------------------------------------------------------------
INSERT INTO stay_options (number_of_nights) VALUES (1), (2), (3), (4), (5);

-- ----------------------------------------------------------------------------
-- bookings (20 rows)
-- ----------------------------------------------------------------------------
-- guest_id in use: 1,2,3,4,5,6,7,8,9,10,12,14  (12 of the 15 guests)
-- room_id  in use: 1,2,3,4,5,6,7,8,9,10,11,14  (12 of the 15 rooms)
-- Every booking_amount = (check_out_date - check_in_date in nights) x
-- that room's room_base_price -- verified by the CHECK query at the foot
-- of this file.
-- ----------------------------------------------------------------------------
INSERT INTO bookings (guest_id, room_id, booking_amount, number_of_guests, check_in_date, check_out_date) VALUES
(1,  1,  195.00, 1, '2026-03-01', '2026-03-04'),  -- 3 nights x 65.00
(1,  5,  396.00, 2, '2026-06-10', '2026-06-14'),  -- 4 nights x 99.00
(2,  3,  285.00, 2, '2026-02-14', '2026-02-17'),  -- 3 nights x 95.00
(3,  9,  560.00, 4, '2026-04-01', '2026-04-05'),  -- 4 nights x 140.00
(4,  6,  450.00, 2, '2026-05-20', '2026-05-25'),  -- 5 nights x 90.00
(5,  11, 880.00, 2, '2026-07-01', '2026-07-05'),  -- 4 nights x 220.00
(5,  2,  130.00, 1, '2026-01-10', '2026-01-12'),  -- 2 nights x 65.00
(6,  10, 725.00, 3, '2026-08-15', '2026-08-20'),  -- 5 nights x 145.00
(7,  4,  285.00, 2, '2026-03-15', '2026-03-18'),  -- 3 nights x 95.00
(8,  7,  460.00, 2, '2026-09-01', '2026-09-06'),  -- 5 nights x 92.00
(9,  14, 291.00, 2, '2026-02-01', '2026-02-04'),  -- 3 nights x 97.00
(10, 8,  360.00, 2, '2026-06-01', '2026-06-05'),  -- 4 nights x 90.00
(10, 1,  130.00, 1, '2026-10-01', '2026-10-03'),  -- 2 nights x 65.00
(1,  9,  700.00, 5, '2026-12-20', '2026-12-25'),  -- 5 nights x 140.00
(2,  14, 194.00, 2, '2026-11-05', '2026-11-07'),  -- 2 nights x 97.00
(3,  5,  594.00, 3, '2026-08-01', '2026-08-07'),  -- 6 nights x 99.00
(6,  3,  190.00, 1, '2026-09-10', '2026-09-12'),  -- 2 nights x 95.00
(9,  11, 660.00, 2, '2026-04-10', '2026-04-13'),  -- 3 nights x 220.00
(12, 10, 145.00, 1, '2026-05-01', '2026-05-02'),  -- 1 night  x 145.00
(14, 4,  380.00, 4, '2026-07-20', '2026-07-24');  -- 4 nights x 95.00

-- ----------------------------------------------------------------------------
-- Verification: booking_amount = nights x room_base_price for every row
-- ----------------------------------------------------------------------------
-- Expected result: 0 rows (no mismatches).
SELECT b.booking_id, b.booking_amount,
       DATEDIFF(b.check_out_date, b.check_in_date) AS nights,
       r.room_base_price,
       DATEDIFF(b.check_out_date, b.check_in_date) * r.room_base_price AS expected_amount
FROM bookings AS b
INNER JOIN room AS r ON b.room_id = r.room_id
WHERE b.booking_amount <> DATEDIFF(b.check_out_date, b.check_in_date) * r.room_base_price;

-- ----------------------------------------------------------------------------
-- Record-count check (see record_count_evidence.md for the captured output)
-- ----------------------------------------------------------------------------
SELECT 'guest' AS table_name, COUNT(*) AS record_count FROM guest
UNION ALL
SELECT 'room', COUNT(*) FROM room
UNION ALL
SELECT 'stay_options', COUNT(*) FROM stay_options
UNION ALL
SELECT 'bookings', COUNT(*) FROM bookings;
