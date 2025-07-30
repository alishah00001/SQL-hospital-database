# Database Management System Project: Hospital Management System

## Project Overview

This project focuses on the design and development of a robust and efficient database system for a hospital management system. The system aims to cater to the needs of the hospital by managing information related to patients, doctors, medical records, appointments, and departments. The implementation leverages T-SQL statements, including triggers, views, stored procedures, system functions, user-defined functions, and `SELECT` statements with `JOINs` and subqueries. A key focus is on database design and normalization to ensure data integrity and accessibility.

## Key Implementation Details and Findings

### 1. Requirements Understanding

The database is designed to store information on:
* **Patients:** Full name, insurance, date of birth, address, and departure date.
* **Doctors:** Full name, department, email, telephone, and specialty.
* **Medical Records:** Past appointments, diagnoses, prescribed medicine, medicine prescribed date, and allergies.
* **Appointments:** Details of patient-doctor appointments.
* **Departments:** Hospital departments.

Client requirements include:
* Patient registration with personal details and a user account (username/password) for a patient portal.
* Booking appointments, with the system checking doctor availability.
* Doctors reviewing past appointments and updating medical records post-appointment.
* Patients providing feedback on doctors.
* Patients being able to cancel and rebook appointments, with status updates from "pending" to "completed" upon attendance.
* Retention of patient data upon departure, with the departure date recorded.

### 2. Database Design and Normalization

The database schema includes the following tables, identified after conceptualizing entities and their relationships:
* `Patients`
* `PatientContactInfo`
* `UserAccounts`
* `Doctors`
* `DoctorsReviews`
* `DoctorSpecialization`
* `Specialization`
* `MedicalHistory`
* `Appointment`
* `AppointmentStatus`
* `DeletedAppointment`
* `Department`

**Normalization:** The database adheres to normalization principles to reduce data redundancy and improve integrity.
* **1NF:** Each table has a unique identifier (e.g., PatientID, RecordID, DoctorID), ensuring each table holds a single concept.
* **2NF:** All non-key attributes are fully functionally dependent on their primary key.
* **3NF:** All attributes depend only on the primary key, and transitive dependencies are removed (e.g., `PatientContactInfo` is separate from `Patient` details).
* `DoctorSpecializations` table handles many-to-many relationships between doctors and specializations.

### 3. Technical Implementations (T-SQL Statements)

**Patient Management:**
* **`Patient` Table:** Includes `PatientID` (PK), `FullName`, `Address`, `DateOfBirth`, `Insurance`, and `DepartureDate` (nullable).
* **`PatientDepartureDate` Stored Procedure:** Updates the `DepartureDate` for a given `PatientID` when a patient leaves the hospital.
* **`UserAccounts` Table:** Stores `UserID` (PK), `PatientID` (FK), `Username` (unique, not null), `PasswordHash`, and `Salt` for secure authentication.
* **`AddPatientWithCredentials` Stored Procedure:** Securely adds new patient credentials by generating a random `Salt` and hashing the password using `SHA2_512` before storing it in `UserAccounts`. This ensures passwords are not easily reversible.
* **`PatientContactInfo` Table:** Stores `ContactID` (PK), `PatientID` (FK), `Email` (optional), and `Telephone` (optional).
* **`RegisteredPatients` Stored Procedure:** Retrieves a full list of registered patients by joining `Patient`, `UserAccounts`, and `PatientContactInfo` tables.

**Doctor and Specialization Management:**
* **`Doctors` Table:** Includes `DoctorID` (PK), `FullName`, `DepartmentID` (FK), `Email` (optional), `Telephone` (optional), and `Specialty`.
* **`Specializations` Table:** Stores `SpecializationID` (PK) and `SpecializationName`.
* **`DoctorSpecializations` Table:** Acts as a junction table with a composite primary key (`DoctorID`, `SpecializationID`) to manage many-to-many relationships between doctors and specializations.

**Appointment Management:**
* **`Appointment` Table:** Contains `AppointmentID` (PK), `PatientID` (FK), `DoctorID` (FK), `AppointmentDate`, and `AppointmentTime`. A `CHECK` constraint ensures `AppointmentDate` is not in the past.
* **`AppointmentStatus` Table:** Stores `StatusID` (PK), `AppointmentID` (FK), and `Status` (with allowed values: 'Pending', 'Cancelled', 'Available', 'Completed').
* **`TR_CancelledAppointment` Trigger:** Automatically updates an appointment's status to 'Available' in `AppointmentStatus` if it is set to 'Cancelled'.
* **`BookAppointment` Stored Procedure:** Allows patients to book appointments. It checks for doctor availability at the specified date and time. If available, it inserts the appointment and sets its status to 'Booked'; otherwise, it returns an error.
* **`DeletedAppointment` Table:** Stores records of completed appointments, with a trigger moving completed appointments from `AppointmentStatus` to this table.

**Medical History and Reviews:**
* **`MedicalHistory` Table:** Stores `RecordID` (PK), `PatientID` (FK), `DoctorID` (FK), `AppointmentID` (FK), `Diagnoses`, `Allergies` (nullable), `Medicines`, `MedicinePrescribedDate`, and `RecordTimestamp`.
* **`DoctorsReviews` Table:** Stores `ReviewID` (PK), `Review` text, and `AppointmentID` (FK) for patient feedback.
* **`UpdateMedicalHistoryAndCompleteAppointment` Stored Procedure:** Updates a patient's medical history (diagnoses, medicines, allergies) after an appointment. Upon update, it changes the appointment status to 'Completed'.
* **Trigger for Patient Age Calculation:** A trigger on the `Patient` table automatically calculates and stores the patient's age based on their `DateOfBirth` upon insertion of new patient data.

**Additional Queries and Functions:**
* **Query for Patients > 40 with Cancer:** A `SELECT` query joining `MedicalHistory` and `Patient` tables retrieves patients with a 'Cancer' diagnosis and an age greater than 40.
* **Stored Procedure to Search Medicine by Name:** Searches for matching character strings in medicine names within `MedicalHistory`, sorted by `MedicinePrescribedDate` in descending order.
* **User-Defined Function for Today's Diagnoses/Allergies:** Returns diagnoses and allergies for patients with appointments on the current system date.
* **Stored Procedure to Update Doctor Details:** Updates an existing doctor's details based on `DoctorID`. Includes error handling if the `DoctorID` is not found.
* **View for Doctor and Appointment Details:** A `VIEW` aggregates information from `Appointment`, `Doctors`, `Department`, `DoctorsReviews`, and `Patient` tables to show all previous and current appointments, doctor details, department, specialty, and reviews.
* **Query for Completed Appointments by Specialty:** A `SELECT` query identifies the number of completed appointments for doctors with a specific specialty, e.g., 'Gastroenterologists'.

### 4. Client Advice and Guidance

* **Data Integrity and Concurrency:**
    * Primary and foreign keys are used to maintain data integrity.
    * Triggers (e.g., `calculatePatientAge`) ensure concurrency and data accuracy.
    * Stored procedures for medical history updates and appointment status changes are wrapped in transactions to maintain consistency.
* **Database Security:**
    * Password hashing with salts (`SHA2_512`) is implemented for secure user authentication.
    * Role-Based Access Control (RBAC) is applied, with a 'Doctor' role created and assigned permissions (e.g., to update medical records).
    * User input sanitization is essential to prevent SQL injection vulnerabilities.
* **Database Backup and Recovery:**
    * Database backups have been performed, and backup files are available.
