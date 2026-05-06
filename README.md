LIBRARY-DB
 Library Reservation System (MySQL)

A simple but robust **database-driven library reservation system** built using MySQL.
It supports book reservations, waitlists, notifications, and automatic queue management.
 Features
 Book reservation system
 Waitlist (queue) handling when books are unavailable
 Notification system for users
 Reservation fulfillment tracking
 Automatic reservation expiry
 Queue progression when books become available
 View to track reservation positions
 
 Database Structure
 1. Members

Stores user information.

* `member_id` (PK)
* `first_name`
* `last_name`
* `email` (unique)
  
 2. Books
Stores book inventory.
 `book_id` (PK)
 `title`
 `available_copies`
 3. Reservations
Tracks all reservations and their status.

* `reservation_id` (PK)
* `member_id` (FK)
* `book_id` (FK)
* `reservation_date`
* `expiry_date`
* `status` (`Pending`, `Ready`, `Fulfilled`, `Cancelled`)

 4. Notifications

Stores messages sent to members.

* `notification_id` (PK)
* `member_id` (FK)
* `message`
* `status` (`Unread`, `Read`)
* `created_at`
 View
 `vw_ReservationQueue`

Displays the waitlist queue per book with position tracking.

Includes:

* Book title
* Member name
* Queue position (using `ROW_NUMBER()`)
* Reservation status
* Expiry date
 Stored Procedures
 1. `ReserveBook(member_id, book_id)`

* If copies are available:

  * Marks reservation as **Ready**
  * Sets expiry date (2 days)
  * Decreases available copies
  * Sends notification
* If unavailable:

  * Adds user to **Pending waitlist**
  * Sends notification
 2. `ProcessNextReservation(book_id)`

* Promotes the next user in queue to **Ready**
* Sets expiry date
* Sends notification
* If no one is waiting:

  * Increases available copies
 3. `FulfillReservation(reservation_id)`

* Marks reservation as **Fulfilled*
 4. `ExpireReservations()`

* Finds expired reservations
* Marks them as **Cancelled**
* Sends notification
* (Can be scheduled using MySQL Event Scheduler)
 Sample Data

Includes:

* 3 members
* 2 books:

  * One available
  * One fully reserved
 Example Usage

```sql
 Reserve books
CALL ReserveBook(1,1);
CALL ReserveBook(2,1);
CALL ReserveBook(3,2);

-- View queue
SELECT * FROM vw_ReservationQueue;

 Process next in queue
CALL ProcessNextReservation(1);

 Expire old reservations
CALL ExpireReservations();

Check notifications
SELECT * FROM Notifications;
``` Design Highlights

* Uses **ENUMs** for controlled status values
* Implements **queue logic** using SQL window functions
* Encapsulates business logic in **stored procedures**
* Maintains **data integrity** with foreign keys
* Separates concerns (data, logic, notifications

 Known Limitations / Improvements

* No transaction handling (can be added for reliability)
* Potential race conditions on concurrent reservations
* Expired reservations should trigger queue reassignment (can be enhanced)
* No API or frontend (database-only implementation
 Future Improvements

* Add transaction support (`START TRANSACTION`)
* Prevent duplicate reservations per user/book
* Add REST API (Node.js / Django)
* Build frontend (React / Vue)
* Automate expiry using MySQL Events
* Add admin dashboard

 Getting Started

1. Copy the SQL script into MySQL
2. Run the script to create the database
3. Execute test queries
4. Modify or extend as needed
 Author
Your Name
License
This project is open-source and available under the MIT License.
