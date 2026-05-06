
DROP DATABASE IF EXISTS ReservationSystem;
CREATE DATABASE ReservationSystem;
USE ReservationSystem;

CREATE TABLE Members (
    member_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name  VARCHAR(50),
    email      VARCHAR(100) UNIQUE
);

CREATE TABLE Books (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255),
    available_copies INT DEFAULT 0
);

CREATE TABLE Reservations (
    reservation_id   INT AUTO_INCREMENT PRIMARY KEY,
    member_id        INT NOT NULL,
    book_id          INT NOT NULL,
    reservation_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    expiry_date      DATE,
    status ENUM('Pending','Ready','Fulfilled','Cancelled') DEFAULT 'Pending',

    FOREIGN KEY (member_id) REFERENCES Members(member_id),
    FOREIGN KEY (book_id)   REFERENCES Books(book_id)
);

CREATE TABLE Notifications (
    notification_id INT AUTO_INCREMENT PRIMARY KEY,
    member_id INT NOT NULL,
    message TEXT NOT NULL,
    status ENUM('Unread','Read') DEFAULT 'Unread',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (member_id) REFERENCES Members(member_id)
);

CREATE VIEW vw_ReservationQueue AS
SELECT
    r.reservation_id,
    b.title,
    CONCAT(m.first_name,' ',m.last_name) AS member_name,
    ROW_NUMBER() OVER (PARTITION BY r.book_id ORDER BY r.reservation_date) AS position,
    r.status,
    r.expiry_date
FROM Reservations r
JOIN Members m ON r.member_id = m.member_id
JOIN Books b   ON r.book_id   = b.book_id
WHERE r.status IN ('Pending','Ready');

DELIMITER $$

-- RESERVE BOOK
CREATE PROCEDURE ReserveBook(IN p_member_id INT, IN p_book_id INT)
BEGIN
    DECLARE copies INT;
    DECLARE book_title VARCHAR(255);

    SELECT available_copies, title INTO copies, book_title
    FROM Books
    WHERE book_id = p_book_id;

    IF copies > 0 THEN

        INSERT INTO Reservations(member_id, book_id, status, expiry_date)
        VALUES (p_member_id, p_book_id, 'Ready', DATE_ADD(CURDATE(), INTERVAL 2 DAY));

        UPDATE Books
        SET available_copies = available_copies - 1
        WHERE book_id = p_book_id;

        INSERT INTO Notifications(member_id, message)
        VALUES (p_member_id, CONCAT('Your reserved book "', book_title, '" is ready for pickup.'));

    ELSE

        INSERT INTO Reservations(member_id, book_id, status)
        VALUES (p_member_id, p_book_id, 'Pending');

        INSERT INTO Notifications(member_id, message)
        VALUES (p_member_id, CONCAT('You have been added to the wait-list for "', book_title, '".'));

    END IF;
END$$


-- PROCESS NEXT IN QUEUE
CREATE PROCEDURE ProcessNextReservation(IN p_book_id INT)
BEGIN
    DECLARE next_res INT;
    DECLARE next_member INT;
    DECLARE book_title VARCHAR(255);

    SELECT title INTO book_title
    FROM Books
    WHERE book_id = p_book_id;

    SELECT reservation_id, member_id INTO next_res, next_member
    FROM Reservations
    WHERE book_id = p_book_id
      AND status = 'Pending'
    ORDER BY reservation_date
    LIMIT 1;

    IF next_res IS NOT NULL THEN

        UPDATE Reservations
        SET status = 'Ready',
            expiry_date = DATE_ADD(CURDATE(), INTERVAL 2 DAY)
        WHERE reservation_id = next_res;

        INSERT INTO Notifications(member_id, message)
        VALUES (next_member, CONCAT('Good news! "', book_title, '" is now available for you.'));

    ELSE

        UPDATE Books
        SET available_copies = available_copies + 1
        WHERE book_id = p_book_id;

    END IF;
END$$


-- FULFILL RESERVATION
CREATE PROCEDURE FulfillReservation(IN p_reservation_id INT)
BEGIN
    UPDATE Reservations
    SET status = 'Fulfilled'
    WHERE reservation_id = p_reservation_id;
END$$


-- EXPIRE RESERVATIONS
CREATE PROCEDURE ExpireReservations()
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE res_id INT;
    DECLARE mem_id INT;
    DECLARE book_title VARCHAR(255);

    DECLARE cur CURSOR FOR
        SELECT r.reservation_id, r.member_id, b.title
        FROM Reservations r
        JOIN Books b ON r.book_id = b.book_id
        WHERE r.status = 'Ready'
          AND r.expiry_date < CURDATE();

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO res_id, mem_id, book_title;
        IF done THEN
            LEAVE read_loop;
        END IF;

        UPDATE Reservations
        SET status = 'Cancelled'
        WHERE reservation_id = res_id;

        INSERT INTO Notifications(member_id, message)
        VALUES (mem_id, CONCAT('Your reservation for "', book_title, '" has expired.'));
    END LOOP;

    CLOSE cur;
END$$

DELIMITER ;

INSERT INTO Members (first_name, last_name, email) VALUES
('Amara', 'Nakato', 'amara@mail.com'),
('David', 'Ochieng', 'david@mail.com'),
('Grace', 'Atim', 'grace@mail.com');

INSERT INTO Books (title, available_copies) VALUES
('Things Fall Apart', 1),
('1984', 0);

CALL ReserveBook(1,1);
CALL ReserveBook(2,1);
CALL ReserveBook(3,2);

SELECT * FROM vw_ReservationQueue;
SELECT * FROM Notifications;

CALL ProcessNextReservation(1);

SELECT * FROM vw_ReservationQueue;
SELECT * FROM Notifications;

CALL ExpireReservations();

SELECT * FROM Notifications;