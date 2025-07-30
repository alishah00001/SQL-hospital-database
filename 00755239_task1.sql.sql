create database AssignPart1
go

-- Create table to store patient information
Create table Patient(
PatientID int primary key, -- Unique identifier for each patient
FullName nvarchar(50) not null, -- Full name of the patient
address nvarchar(250) not null, -- Address of the patient
DateOfBirth date not null, -- Date of birth of the patient
insurance nvarchar(250) not null, -- Insurance information of the patient
DepartureDate DATE NULL, -- Departure date of the patient (nullable)
);
-- Add Age column to the Patient tabl
ALTER TABLE Patient
ADD Age INT;



-- Create table to store user accounts information
CREATE TABLE UserAccounts (
    UserID INT PRIMARY KEY, -- Unique identifier for each user account
    PatientID INT FOREIGN KEY REFERENCES Patient,  -- Foreign key referencing the Patient table
    username NVARCHAR(200) UNIQUE NOT NULL,  -- Username of the user account (unique constraint)
    passwordHash binary(64) NOT NULL, -- Hashed password of the user account
    salt NVARCHAR(50) NOT NULL  -- Salt used for hashing the password
);



-- Stored procedure to add patients with hashed password and salt
CREATE PROCEDURE AddPatientWithCredentials
    @UserID INT, -- ID of the user account
    @PatientID INT, -- ID of the patient
    @Username NVARCHAR(200), -- Username for the user account
    @Password NVARCHAR(200) -- Password for the user account
AS
BEGIN

-- Declare variables to store salt and hashed password
    DECLARE @Salt NVARCHAR(50);
    DECLARE @HashedPassword binary(200);

    -- Generate salt
    SET @Salt = HASHBYTES('SHA2_512', CONVERT(VARCHAR(36), NEWID()));

    -- Hash password with salt
    SET @HashedPassword = HASHBYTES('SHA2_512', @Password + @Salt);

    -- Add the user with hashed password and salt
    INSERT INTO UserAccounts (UserID, PatientID, username, passwordHash, salt)
    VALUES (@UserID, @PatientID, @Username, @HashedPassword, @Salt);
END;



-- Create table PatientContactInfo to store contact information of patients
create table PatientContactInfo(
contactID int primary key, -- Primary key for the contact information
PatientID int foreign key references Patient,  -- Foreign key referencing PatientID in the Patient table
email nvarchar(200),  -- Email address of the patient
Telephone bigint, -- Telephone number of the patient
);



-- Create a stored procedure to update the departure date of a patient
Create procedure PatientDepartureDate
@PatientID int, -- Input parameter: PatientID of the patient
@DepartureDate date -- Input parameter: Departure date to be updated
as
begin
 -- Update the DepartureDate for the specified PatientID
    update Patients
	Set DepartureDate=@DepartureDate
	where PatientID=@PatientID
	end;



-- Create a stored procedure to retrieve registered patients along with their contact information
CREATE PROCEDURE RegisteredPatients
AS
BEGIN
  -- Select patient information along with their username, email, and telephone from related tables
    SELECT
        p.PatientID,
        p.FullName,
        p.address,
        p.DateOfBirth,
        p.insurance,
        p.DepartureDate,
        u.username,
        c.email,
        c.Telephone
    FROM Patient p
    inner JOIN UserAccounts u ON p.PatientID = u.PatientID
    inner JOIN PatientContactInfo c ON p.PatientID = c.PatientID
    ORDER BY p.PatientID;-- Order the results by PatientID
END;

exec  RegisteredPatients;


-- Create a table to store departments
Create table department (
departmentID int primary key,
departmentName nvarchar(100) not null,
);


-- Create a table to store doctors
Create table Doctors(
DoctorID int primary key, -- Unique identifier for each doctor
FullName nvarchar(200) not null,-- Full name of the doctor
departmentID int FOREIGN KEY REFERENCES department(departmentID) NOT NULL, -- ID of the department the doctor belongs to -- Foreign key constraint referencing the department table
email nvarchar(100),-- Email address of the doctor
telephone bigint, -- Telephone number of the doctor
Specialty nvarchar(100) not null, -- Specialty of the doctor
);



-- Create a table to store specializations
CREATE TABLE Specializations (
    SpecializationID INT IDENTITY(1,1) PRIMARY KEY,-- Unique identifier for each specialization, automatically incremented
    SpecializationName NVARCHAR(255) NOT NULL -- Name of the specialization, cannot be NULL
);


-- Create a table to store the specializations of doctors
CREATE TABLE DoctorSpecializations (
    DoctorID INT, -- Foreign key referencing the DoctorID in the Doctors table
    SpecializationID INT, -- Foreign key referencing the SpecializationID in the Specializations table
    PRIMARY KEY (DoctorID, SpecializationID), -- Composite primary key composed of DoctorID and SpecializationID
    FOREIGN KEY (DoctorID) REFERENCES Doctors(DoctorID),  -- Foreign key constraint referencing the DoctorID column in the Doctors table
    FOREIGN KEY (SpecializationID) REFERENCES Specializations(SpecializationID)  -- Foreign key constraint referencing the SpecializationID column in the Specializations table
);



-- Create a table to store appointments
CREATE TABLE Appointment (
    AppointmentID INT  PRIMARY KEY,  -- Unique identifier for each appointment
    PatientID INT FOREIGN KEY (PatientID) REFERENCES Patient(PatientID) not null, -- Foreign key referencing the PatientID in the Patient table
    DoctorID INT FOREIGN KEY (DoctorID) REFERENCES Doctors(DoctorID)  not null,-- Foreign key referencing the DoctorID in the Doctors table
    AppointmentDate DATE not null,-- Date of the appointment
    AppointmentTime TIME not null, -- Time of the appointment
);
-- Add a check constraint to ensure that the AppointmentDate is not in the past
Alter table appointment
add  CONSTRAINT CHECK_AppointmentDate CHECK (AppointmentDate >= CAST(GETDATE() AS DATE));




-- Create a table to store appointment statuses
CREATE TABLE AppointmentStatus (
    StatusID INT IDENTITY(1,1) PRIMARY KEY, -- Unique identifier for each status
    AppointmentID INT, -- Foreign key referencing the AppointmentID in the Appointment table
     Status VARCHAR(50) NOT NULL CHECK (Status IN ('Pending', 'Cancelled', 'Available','Completed','Booked')),-- Status of the appointment with a check constraint
    FOREIGN KEY (AppointmentID) REFERENCES Appointment(AppointmentID)-- Establishing a foreign key constraint
);



-- this table is used to store the appointments whose status is completed and is removed from the Appointment status table
CREATE TABLE DeletedAppointment (
    DeletedStatusID INT IDENTITY(1,1) PRIMARY KEY,-- Unique identifier 
    AppointmentID INT foreign key references Appointment(AppointmentID),-- Foreign key referencing the AppointmentID in the Appointment table
    Status VARCHAR(50), -- Status of the deleted appointment
    DeletionDate DATETIME DEFAULT GETDATE()-- Date and time when the appointment was deleted, set to the current date and time by default
);



CREATE TRIGGER trg_AfterStatusUpdate
ON AppointmentStatus
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if the status has been updated to 'Completed'
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.StatusID = d.StatusID WHERE i.Status = 'Completed')
    BEGIN
        -- Insert the completed appointment record into DeletedAppointment
        INSERT INTO DeletedAppointment (AppointmentID, Status)
        SELECT AppointmentID, Status
        FROM inserted
        WHERE Status = 'Completed';

        -- Delete the completed appointment record from AppointmentStatus
        DELETE FROM AppointmentStatus
        WHERE StatusID IN (SELECT StatusID FROM inserted WHERE Status = 'Completed');
    END
END;
GO


--Procedure to book an appointment for a patient with a doctor
CREATE PROCEDURE BookAppointment
  @PatientID INT,-- ID of the patient
  @DoctorID INT,-- ID of the doctor
  @AppointmentDate DATE,-- Date of the appointment
  @AppointmentID INT,-- ID of the appointment
  @AppointmentTime TIME-- Time of the appointment
AS
BEGIN
  -- Check if the appointment slot is available
  IF NOT EXISTS (
    SELECT * FROM Appointment
    WHERE DoctorID = @DoctorID 
    AND AppointmentDate = @AppointmentDate 
    AND AppointmentTime = @AppointmentTime
  )
  BEGIN
    INSERT INTO Appointment (AppointmentID, PatientID, DoctorID, AppointmentDate, AppointmentTime)
    VALUES (@AppointmentID, @PatientID, @DoctorID, @AppointmentDate, @AppointmentTime);
     
    -- Assuming you have an AppointmentStatus table and logic implemented for it.
    INSERT INTO AppointmentStatus (AppointmentID, Status)
    VALUES (@AppointmentID, 'Booked');

    SELECT 'Appointment booked successfully.' AS Message;
  END
  ELSE
  BEGIN
    SELECT 'Doctor not available at the selected time.' AS Message;
  END
END;



--Table to store medical history records for patients
CREATE TABLE MedicalHistory (
    RecordID INT primary key,-- Unique identifier for each medical record
    PatientID INT NOT NULL, -- ID of the patient associated with this record
    DoctorID INT NOT NULL,-- ID of the doctor who created this record
    AppointmentID INT NOT NULL, -- ID of the appointment associated with this record
    Diagnoses NVARCHAR(100) NOT NULL,-- Diagnoses provided by the doctor
    Allergies NVARCHAR(100), -- Allergies reported by the patient
    Medicines NVARCHAR(500) not null,-- Medicines prescribed for the patient
    MedicinePrescribedDate DATE NOT NULL, -- Date when medicines were prescribed
    RecordTimestamp DATETIME DEFAULT GETDATE(), -- Timestamp indicating when the record was created
    FOREIGN KEY (PatientID) REFERENCES Patient(PatientID),-- Reference to the patient table
    FOREIGN KEY (DoctorID) REFERENCES Doctors(DoctorID),-- Reference to the doctors table
    FOREIGN KEY (AppointmentID) REFERENCES Appointment(AppointmentID) -- Reference to the appointment table
);


--Table to store reviews for doctor
CREATE TABLE DoctorReviews(
  reviewID INT IDENTITY(1,1) PRIMARY KEY, -- Unique identifier for each review
  Review NVARCHAR(200),-- Text content of the review
  AppointmentID INT FOREIGN KEY REFERENCES Appointment(AppointmentID)-- Reference to the appointment table
);


--Procedure to update medical history and mark appointment as completed
CREATE PROCEDURE UpdateMedicalHistoryAndCompleteAppointment
 @DoctorID INT, -- ID of the doctor associated with the appointment
 @AppointmentID INT,-- ID of the appointment to update
 @RecordID INT,-- ID for the medical history record
 @Diagnoses NVARCHAR(MAX), -- Diagnoses for the appointment
 @Medicines NVARCHAR(MAX), -- Medicines prescribed for the appointment
 @Allergies NVARCHAR(MAX), -- Allergies noted during the appointment
 @Review NVARCHAR(200) = NULL -- Added parameter for review, default NULL if not provided
AS
BEGIN
 SET NOCOUNT ON;

  -- Verify if the appointment exists and is associated with the specified doctor
  IF NOT EXISTS (
    SELECT * 
    FROM Appointment
    WHERE AppointmentID = @AppointmentID
      AND DoctorID = @DoctorID
  )
  BEGIN
    RAISERROR('Invalid appointment or doctor.', 16, 1);
    RETURN;
  END

  -- Check the current status of the appointment to ensure it is 'Booked'
  DECLARE @CurrentStatus NVARCHAR(50);
  SELECT @CurrentStatus = Status
  FROM AppointmentStatus
  WHERE AppointmentID = @AppointmentID;

  IF @CurrentStatus IS NULL OR @CurrentStatus <> 'Booked'
  BEGIN
    RAISERROR('Appointment is not in a valid state to update medical history.', 16, 1);
    RETURN;
  END

  -- Update the MedicalHistory
  INSERT INTO MedicalHistory (PatientID, RecordID, DoctorID, AppointmentID, Diagnoses, Allergies, Medicines, MedicinePrescribedDate)
  SELECT PatientID, @RecordID, @DoctorID, @AppointmentID, @Diagnoses, @Allergies, @Medicines, GETDATE()
  FROM Appointment
  WHERE AppointmentID = @AppointmentID;

  -- Update the AppointmentStatus to 'Completed'
  UPDATE AppointmentStatus
  SET Status = 'Completed'
  WHERE AppointmentID = @AppointmentID;
  -- Return a success message
  SELECT 'Medical history updated, appointment marked as completed' AS Message;
END;
GO





  ---List all the patients with older than 40 and have Cancer in diagnosis.
  ---Trigger to calculate age of newly inserted patients
  CREATE TRIGGER CalculatePatientAge
ON Patient
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @PatientID INT, @DateOfBirth DATE;

    -- Get the newly inserted patient's ID and date of birth
    SELECT @PatientID = PatientID, @DateOfBirth = DateOfBirth
    FROM inserted;

    -- Calculate the age
	declare @age int;
    SET @Age = DATEDIFF(YEAR, @DateOfBirth, GETDATE());

    -- Update the Patient table with the calculated age
    UPDATE Patient
    SET Age = @Age
    WHERE PatientID = @PatientID;
END;




---Query to list all patients older than 40 with a diagnosis of Cancer
SELECT p.FullName, p.DateOfBirth, p.Age, mh.Diagnoses
FROM Patient p
INNER JOIN MedicalHistory mh ON p.PatientID = mh.PatientID
WHERE p.Age > 40
AND mh.Diagnoses LIKE '%Cancer%';


select * from MedicalHistory where Diagnoses ='Cancer' ; 






----- The hospital also requires stored procedures or user-defined functions to do the following things:
----a) Search the database of the hospital for matching character strings by name of medicine. Results should be sorted with most recent medicine prescribed date first.

CREATE PROCEDURE SearchMedicineByName
    @MedicineName NVARCHAR(500)
AS
BEGIN
    SELECT mh.PatientID, mh.DoctorID, mh.AppointmentID, mh.Medicines, mh.MedicinePrescribedDate
    FROM MedicalHistory mh
    WHERE mh.Medicines LIKE '%' + @MedicineName + '%'
    ORDER BY mh.MedicinePrescribedDate DESC;
END;

EXEC SearchMedicineByName @MedicineName = 'Sumatriptan';




----) Return a full list of diagnosis and allergies for a specific patient who has an appointment today (i.e., the system date when the query is run)
CREATE FUNCTION GetTodayAppointmentDetails()
RETURNS TABLE
AS
RETURN
(
    SELECT 
        p.PatientID, 
        p.FullName, 
        a.AppointmentDate, 
        a.AppointmentTime, 
        mh.Diagnoses, 
        mh.Allergies
    FROM Patient p
    INNER JOIN Appointment a ON p.PatientID = a.PatientID
    INNER JOIN MedicalHistory mh ON p.PatientID = mh.PatientID
    WHERE CAST(a.AppointmentDate AS DATE) = CAST(GETDATE() AS DATE)
);
SELECT * FROM GetTodayAppointmentDetails();




  ----c) Update the details for an existing doctor
  CREATE PROCEDURE UpdateDoctorDetails
(
  @DoctorID INT,
  @FullName NVARCHAR(200),
  @DepartmentID INT,
  @Email NVARCHAR(100),
  @Telephone BIGINT,
  @Specialty NVARCHAR(100)
)
AS
BEGIN
  -- Update the Doctors table
  UPDATE Doctors
  SET FullName = @FullName,
  DepartmentID = @DepartmentID,
  Email = @Email,
  Telephone = @Telephone,
  Specialty = @Specialty
  WHERE DoctorID = @DoctorID;

  -- Check if rows were affected (optional)
  IF @@ROWCOUNT = 0
  BEGIN
    RAISERROR('Doctor with ID %d not found.', 16, 1, @DoctorID);
    RETURN;
  END
  SELECT 'Doctor details updated successfully.' AS Message;
END;
EXEC UpdateDoctorDetails
  @DoctorID = 2,  -- Replace with the actual doctor ID
  @FullName = 'Dr. Jane Smith',
  @DepartmentID = 1,  -- Replace with the department ID
  @Email = 'jane.smith@hospital.com',
  @Telephone = 1234567890,
  @Specialty = 'Cardiology';
 
 ------d) Delete the appointment who status is already completed.


  ---already did above
  ----5. The hospitals wants to view the appointment date and time, showing all previous
---and current appointments for all doctors, and including details of the department 
----(the doctor is associated with), doctor’s specialty and any associate review/feedback 
----given for a doctor. You should create a view containing all the required information.
CREATE VIEW DoctorsAppointmentsDetails AS
SELECT 
    d.FullName AS DoctorName,
    d.Specialty,
    dep.departmentName AS Department,
    a.AppointmentDate,
    a.AppointmentTime,
    dr.Review AS DoctorReview,
    p.FullName AS PatientName,
    p.PatientID,
    da.Status AS DeletedStatus,
    da.DeletionDate AS DeletionDate
FROM Appointment a
INNER JOIN Doctors d ON a.DoctorID = d.DoctorID
INNER JOIN department dep ON d.departmentID = dep.departmentID
LEFT JOIN DoctorReviews dr ON a.AppointmentID = dr.AppointmentID
INNER JOIN Patient p ON a.PatientID = p.PatientID
LEFT JOIN DeletedAppointment da ON a.AppointmentID = da.AppointmentID;

SELECT * FROM DoctorsAppointmentsDetails
ORDER BY AppointmentDate DESC, AppointmentTime DESC;



--Create a trigger so that the current state of an appointment can be changed to available when it is cancelled.

CREATE TRIGGER TR_CancelledAppointment
ON AppointmentStatus
AFTER UPDATE
AS
BEGIN
    IF UPDATE(Status)
    BEGIN
        DECLARE @CancelledStatus VARCHAR(50) = 'Cancelled';
        UPDATE a
        SET a.Status = 'Available'
        FROM AppointmentStatus AS a
        INNER JOIN inserted AS i ON a.AppointmentID = i.AppointmentID
        WHERE i.Status = @CancelledStatus;
    END
END;





 ----Write a select query which allows the hospital to identify the number of 
----completed appointments with the specialty of doctors as ‘Gastroenterologists’.
CREATE PROCEDURE CountCompletedGastroAppointments
AS
BEGIN
    SELECT COUNT(da.AppointmentID) AS CompletedGastroAppointments
    FROM DeletedAppointment da
    INNER JOIN Appointment a ON da.AppointmentID = a.AppointmentID
    INNER JOIN Doctors d ON a.DoctorID = d.DoctorID
    WHERE d.Specialty = 'Gastroenterologists';
END;
GO

EXEC CountCompletedGastroAppointments;





----creating user login for each doctor to update medical history
CREATE SCHEMA
MedicalHistoryOfPatients; 
GO
ALTER SCHEMA MedicalHistoryOfPatients TRANSFER dbo.UpdateMedicalHistoryAndCompleteAppointment;

CREATE LOGIN DrMichaelJohnson
WITH PASSWORD = 'djsegvwdue20!';



--- creating role doctor
create role Doctor;
GRANT SELECT, UPDATE, INSERT ON SCHEMA :: MedicalHistoryOfPatients
TO Doctor

--- now adding above user login into doctor role
ALTER ROLE Doctor ADD MEMBER DrMichaelJohnson;

----from here sample data starts which is used to put into the tables and stored procedures to check its functionality 

select * from Patient;
INSERT INTO Patient (PatientID, FullName, Address, DateOfBirth, Insurance, DepartureDate, Age)
VALUES
    
    (10, 'ALI MURTAZA', '901 Maple St, Ruralville', '1964-04-22', '567 Insurance', NULL, NULL);
    (1, 'John Doe', '123 Main St, Cityville', '1980-05-15', 'ABC Insurance', NULL, NULL),
    (2, 'Jane Smith', '456 Elm St, Townsville', '1975-10-20', 'XYZ Insurance', NULL, NULL),
    (3, 'Alice Johnson', '789 Oak St, Villagetown', '1990-03-08', '123 Insurance', NULL, NULL),
    (4, 'Michael Brown', '567 Pine St, Hamletville', '1988-07-03', '456 Insurance', NULL, NULL),
    (5, 'Emily Williams', '890 Cedar St, Countryside', '1972-12-30', '789 Insurance', NULL, NULL),
    (6, 'David Jones', '234 Birch St, Suburbia', '1995-09-18', '234 Insurance', NULL, NULL),
    (7, 'Sarah Garcia', '901 Maple St, Ruralville', '1984-04-22', '567 Insurance', NULL, NULL);


	-- Sample data for UserAccounts table with unique salt names
DECLARE @SaltPrefix NVARCHAR(10) = 'ALIASSIGN1';

-- Inserting data for 7 users
INSERT INTO UserAccounts (UserID, PatientID, username, passwordHash, salt)
VALUES
    (1, 1, 'john_doe', 0x6C7280B3C4E97A, @SaltPrefix + '1'),
    (2, 2, 'jane_smith', 0x8F32A1B2C3D4E5, @SaltPrefix + '2'),
    (3, 3, 'alice_johnson', 0xABDE87C4E3F6A9, @SaltPrefix + '3'),
    (4, 4, 'bob_jackson', 0x923F6A2B4C1D7E, @SaltPrefix + '4'),
    (5, 5, 'sarah_miller', 0x5C2E7F1A3B9D8C, @SaltPrefix + '5'),
    (6, 6, 'michael_brown', 0x7A8F3B9D5C2E4F, @SaltPrefix + '6'),
    (7, 7, 'emily_taylor', 0xD8C7E9A2B6F3D5, @SaltPrefix + '7');

	-- Execute the stored procedure to add a patient with credentials
DECLARE @UserID INT = 9; -- Assuming UserID
DECLARE @PatientID INT = 9; -- Assuming PatientID
DECLARE @Username NVARCHAR(200) = 'Student_ALI'; -- Assuming Username
DECLARE @Password NVARCHAR(200) = 'MANIBheheA3'; -- Assuming Password

EXEC AddPatientWithCredentials @UserID, @PatientID, @Username, @Password;


SELECT * FROM UserAccounts;



-- Sample data for PatientContactInfo table
INSERT INTO PatientContactInfo (contactID, PatientID, email, Telephone)
VALUES
    (1, 1, 'john_doe@example.com', 1234567890),
    (2, 2, 'jane_smith@example.com', 9876543210),
    (3, 3, 'alice_johnson@example.com', 1112223333),
    (4, 4, 'bob_jackson@example.com', 4445556666),
    (5, 5, 'sarah_miller@example.com', 7778889999),
    (6, 6, 'michael_brown@example.com', 1231231234),
    (7, 7, 'emily_taylor@example.com', 4564564567);


	-- Execute the RegisteredPatients stored procedure
EXEC RegisteredPatients;


-- Sample data for department table
INSERT INTO department (departmentID, departmentName)
VALUES
    (1, 'Cardiology'),
    (2, 'Neurology'),
    (3, 'Orthopedics'),
    (4, 'Oncology'),
    (5, 'Pediatrics'),
    (6, 'Internal Medicine'),
    (7, 'Surgery');

	-- Sample data for Doctors table
INSERT INTO Doctors (DoctorID, FullName, departmentID, email, telephone, Specialty)
VALUES

    (9, 'Dr. Michael Johnson', 1, 'michael.johnson@example.com', 1234567890, 'Gastroenterologists');
    (2, 'Dr. Jessica Williams', 2, 'jessica.williams@example.com', 2345678901, 'Neurologist'),
    (3, 'Dr. Christopher Davis', 3, 'christopher.davis@example.com', 3456789012, 'Orthopedic Surgeon'),
    (4, 'Dr. Elizabeth Taylor', 4, 'elizabeth.taylor@example.com', 4567890123, 'Oncologist'),
    (5, 'Dr. Daniel Martinez', 5, 'daniel.martinez@example.com', 5678901234, 'Pediatrician'),
    (6, 'Dr. Amanda Garcia', 6, 'amanda.garcia@example.com', 6789012345, 'Internist'),
    (7, 'Dr. Joshua Hernandez', 7, 'joshua.hernandez@example.com', 7890123456, 'Surgeon');


	-- Sample data for Specializations table
INSERT INTO Specializations (SpecializationName)
VALUES
('Gastroenterologists');
    ('Cardiology'),
    ('Neurology'),
    ('Orthopedic Surgery'),
    ('Oncology'),
    ('Pediatrics'),
    ('Internal Medicine'),
    ('General Surgery')
	('Gastroenterologists');


	-- Sample data for DoctorSpecializations table
INSERT INTO DoctorSpecializations (DoctorID, SpecializationID)
VALUES
(9,8); 
    (1, 1),  -- Dr. Michael Johnson - Cardiology
    (2, 2),  -- Dr. Jessica Williams - Neurology
    (3, 3),  -- Dr. Christopher Davis - Orthopedic Surgery
    (4, 4),  -- Dr. Elizabeth Taylor - Oncology
    (5, 5),  -- Dr. Daniel Martinez - Pediatrics
    (6, 6),  -- Dr. Amanda Garcia - Internal Medicine
    (7, 7),
	(9,8);  -- Dr. Joshua Hernandez - General Surgery


	-- Sample data for Appointment table
INSERT INTO Appointment (AppointmentID, PatientID, DoctorID, AppointmentDate, AppointmentTime)
VALUES
 (9, 1, 9, '2024-04-15', '09:00:00');
    (1, 1, 1, '2024-03-25', '09:00:00'),  -- Appointment for PatientID 1 with DoctorID 1 on 2024-03-25 at 09:00 AM
    (2, 2, 3, '2024-03-26', '10:30:00'),  -- Appointment for PatientID 2 with DoctorID 3 on 2024-03-26 at 10:30 AM
    (3, 3, 5, '2024-03-27', '13:00:00'),  -- Appointment for PatientID 3 with DoctorID 5 on 2024-03-27 at 01:00 PM
    (4, 4, 2, '2024-03-28', '11:15:00'),  -- Appointment for PatientID 4 with DoctorID 2 on 2024-03-28 at 11:15 AM
    (5, 5, 4, '2024-03-29', '14:30:00'),  -- Appointment for PatientID 5 with DoctorID 4 on 2024-03-29 at 02:30 PM
    (6, 6, 6, '2024-03-30', '16:45:00'),  -- Appointment for PatientID 6 with DoctorID 6 on 2024-03-30 at 04:45 PM
    (7, 7, 7, '2024-03-31', '15:20:00');  -- Appointment for PatientID 7 with DoctorID 7 on 2024-03-31 at 03:20 PM
	select * from  AppointmentStatus;
	delete * s;
	DELETE FROM AppointmentStatus;
	select* from DeletedAppointment;
	drop * from Appointment;
	EXEC BookAppointment @PatientID = 8, @DoctorID = 4, @AppointmentID = 501, @AppointmentDate = '2024-04-23', @AppointmentTime = '02:00:00';
	EXEC BookAppointment @PatientID = 6, @DoctorID = 7, @AppointmentID = 121, @AppointmentDate = '2025-04-11', @AppointmentTime = '10:00:00';
	EXEC BookAppointment @PatientID = 1, @DoctorID = 1, @AppointmentID = 3226, @AppointmentDate = '2025-01-25', @AppointmentTime = '11:00:00';
	exec  BookAppointment  @PatientID=1;
-- Execute the stored procedure with test data
EXEC UpdateMedicalHistoryAndCompleteAppointment
    @DoctorID = 4,
    @AppointmentID =631,
    @RecordID = 16,
    @Diagnoses = 'Cancer',
    @Medicines = 'CancerMedicine',
    @Allergies = 'not allergies';
    

		EXEC BookAppointment @PatientID = 2, @DoctorID = 4, @AppointmentID = 1237, @AppointmentDate = '2024-09-22', @AppointmentTime = '02:00:00';





----as a sample data we taken 7 appointments 

	EXEC BookAppointment @PatientID = 1, @DoctorID = 1, @AppointmentID = 433, @AppointmentDate = '2026-08-25', @AppointmentTime = '09:00:00';
	EXEC BookAppointment @PatientID = 2, @DoctorID = 2, @AppointmentID = 434, @AppointmentDate = '2026-08-26', @AppointmentTime = '10:30:00';
	EXEC BookAppointment @PatientID = 3, @DoctorID = 3, @AppointmentID = 435, @AppointmentDate = '2026-08-27', @AppointmentTime = '11:45:00';
	EXEC BookAppointment @PatientID = 4, @DoctorID = 4, @AppointmentID = 436, @AppointmentDate = '2026-08-28', @AppointmentTime = '14:00:00';
	EXEC BookAppointment @PatientID = 5, @DoctorID = 5, @AppointmentID = 437, @AppointmentDate = '2026-08-29', @AppointmentTime = '15:30:00';
	EXEC BookAppointment @PatientID = 6, @DoctorID = 6, @AppointmentID = 438, @AppointmentDate = '2026-08-30', @AppointmentTime = '16:45:00';
	EXEC BookAppointment @PatientID = 7, @DoctorID = 7, @AppointmentID = 439, @AppointmentDate = '2026-08-31', @AppointmentTime = '17:30:00';


	--- sample data for updating medical history 
INSERT INTO MedicalHistory (RecordID, PatientID, DoctorID, AppointmentID, Diagnoses, Allergies, Medicines, MedicinePrescribedDate)
VALUES
(1, 1, 1, 433, 'Type 2 Diabetes', 'Peanuts', 'Metformin', '2023-01-15'),
(2, 2, 2, 434, 'Hypertension', 'Penicillin', 'Lisinopril', '2023-02-20'),
(3, 3, 3, 435, 'Asthma', 'Dust', 'Albuterol', '2023-03-10'),
(4, 4, 4, 436, 'Breast Cancer', NULL, 'Tamoxifen', '2023-04-05'),
(5, 5, 5, 437, 'Osteoarthritis', 'Shellfish', 'Ibuprofen', '2023-05-12'),
(6, 6, 6, 438, 'Bronchitis', 'Mold', 'Amoxicillin', '2023-06-20'),
(7, 7, 7, 439, 'Migraine', 'None', 'Sumatriptan', '2023-07-08');





EXEC BookAppointment 1, 201, '2024-04-01', 1001, '10:00:00';
