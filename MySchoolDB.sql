

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'MYSchoolDB')
BEGIN
    CREATE DATABASE MYSchoolDB;
END
GO

USE MYSchoolDB
GO

-----------------------------------------
-- independent Tables (no foreign keys)
-----------------------------------------

-- 1. Subjects
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Subjects')
BEGIN
    CREATE TABLE Subjects (
        Subject_Id NVARCHAR(10) PRIMARY KEY,          -- Manual code: 'MATH', 'SCI', ...
        Subject_Name_Ar NVARCHAR(50) NOT NULL,
        Subject_Name_En VARCHAR(50) NOT NULL,
        Required_Level TINYINT NOT NULL,              -- minimum level for the subject
        CONSTRAINT CHK_Minimum_Level CHECK (Required_Level >= 1 AND Required_Level <= 12)   -- [1]
    );
END
GO

-- 2. Teacher
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Teacher')
BEGIN
    CREATE TABLE Teacher (
        Teacher_Id INT PRIMARY KEY,
        First_name NVARCHAR(30) NOT NULL,
        Last_name NVARCHAR(30) NOT NULL,
        Email VARCHAR(50) NOT NULL UNIQUE,
        Phone_Number VARCHAR(20) NOT NULL UNIQUE,
        hire_date DATE NOT NULL DEFAULT GETDATE(),
        specialization NVARCHAR(100),
        is_full_time BIT DEFAULT 1,
        qualification NVARCHAR(50) NOT NULL
    );
END
GO

-- 3. class
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'class')
BEGIN
    CREATE TABLE class (
        class_Letter CHAR(1) NOT NULL,
        Student_Capacity TINYINT NOT NULL,
        Class_Level TINYINT NOT NULL,
        Room_Number VARCHAR(20) NOT NULL,
        CONSTRAINT CHK_Class_Level CHECK (Class_Level >= 1 AND Class_Level <= 12),
        CONSTRAINT PK_Class PRIMARY KEY (Class_Level, class_Letter)
    );
END
GO

-- 4. Parents
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Parents')
BEGIN
    CREATE TABLE Parents (
        Parental_Id INT PRIMARY KEY,
        First_name NVARCHAR(30) NOT NULL,
        Last_name NVARCHAR(30) NOT NULL,
        Email VARCHAR(100) NOT NULL UNIQUE,
        Phone_Number VARCHAR(20) NOT NULL UNIQUE,
        relationship NVARCHAR(30) NOT NULL,
        Occupation NVARCHAR(50) NOT NULL
    );
END
GO

-- 5. Governorates
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Governorates')
BEGIN
    CREATE TABLE Governorates (
        Gov_Id TINYINT PRIMARY KEY,                   -- Manual IDs 1..12
        Gov_Name_Ar NVARCHAR(50) NOT NULL,
        Gov_Name_En VARCHAR(50) NOT NULL
    );
END
GO

IF NOT EXISTS (SELECT * FROM Governorates)
BEGIN
    INSERT INTO Governorates (Gov_Id, Gov_Name_Ar, Gov_Name_En) VALUES
    (1, N'عمان', 'Amman'),   (2, N'الزرقاء', 'Zarqa'),
    (3, N'إربد', 'Irbid'),    (4, N'البلقاء', 'Balqa'),
    (5, N'مادبا', 'Madaba'),  (6, N'الكرك', 'Karak'),
    (7, N'الطفيلة', 'Tafilah'),(8, N'معان', 'Ma''an'),
    (9, N'العقبة', 'Aqaba'),  (10, N'المفرق', 'Mafraq'),
    (11, N'جرش', 'Jerash'),   (12, N'عجلون', 'Ajloun');
END
GO

------------------------------------------
-- dependent Tables (have foreign keys)
------------------------------------------

-- 6. Address
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Address')
BEGIN
    CREATE TABLE Address (
        Address_Id INT PRIMARY KEY IDENTITY(1,1),
        Gov_Id TINYINT NOT NULL,
        District NVARCHAR(50) NOT NULL,
        Street NVARCHAR(50) NOT NULL,
        Building_No NVARCHAR(10) NOT NULL,
        CONSTRAINT FK_Address_Gov FOREIGN KEY (Gov_Id) REFERENCES Governorates(Gov_Id),
        CONSTRAINT UQ_Location UNIQUE (Gov_Id, District, Street, Building_No)
    );
END
GO

-- 7. Courses
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Courses')
BEGIN
    CREATE TABLE Courses (
        Subject_Id NVARCHAR(10) NOT NULL,
        Learning_Materials NVARCHAR(MAX) NOT NULL,
        [Description] NVARCHAR(MAX) NOT NULL,
        Course_Level TINYINT NOT NULL,
        CONSTRAINT CHK_Course_Level CHECK (Course_Level >= 1 AND Course_Level <= 12),
        CONSTRAINT PK_Courses PRIMARY KEY (Subject_Id, Course_Level),
        CONSTRAINT FK_Course_Subject FOREIGN KEY (Subject_Id)
            REFERENCES Subjects(Subject_Id) ON UPDATE CASCADE
    );
END
GO

-- 8. Student
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Student')
BEGIN
    CREATE TABLE Student (
        Student_Id INT PRIMARY KEY,
        First_Name NVARCHAR(30) NOT NULL,
        Last_Name NVARCHAR(30) NOT NULL,
        Date_of_Birth DATE NOT NULL,
        Gender CHAR(1) CHECK (Gender IN ('M', 'F')),
        Blood_Type VARCHAR(5),
        Medical_Conditions NVARCHAR(MAX),
        Class_Level TINYINT NOT NULL,
        class_Letter CHAR(1) NOT NULL,
        Parental_Id INT NOT NULL,
        CONSTRAINT FK_Student_Class FOREIGN KEY (Class_Level, class_Letter)
            REFERENCES class(Class_Level, class_Letter) ON UPDATE CASCADE,
        CONSTRAINT FK_Student_Parents FOREIGN KEY (Parental_Id)
            REFERENCES Parents(Parental_Id) ON UPDATE CASCADE
    );
END
GO

-- 9. Student_Addresses (junction)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Student_Addresses')
BEGIN
    CREATE TABLE Student_Addresses (
        Student_Id INT NOT NULL,
        Address_Id INT NOT NULL,
        Main_Address BIT DEFAULT 0,
        CONSTRAINT PK_Student_Addresses PRIMARY KEY (Student_Id, Address_Id),
        CONSTRAINT FK_SA_Student FOREIGN KEY (Student_Id)
            REFERENCES Student(Student_Id) ON UPDATE CASCADE ON DELETE CASCADE,
        CONSTRAINT FK_SA_Address FOREIGN KEY (Address_Id)
            REFERENCES Address(Address_Id) ON UPDATE CASCADE
    );
END
GO

-- 10. Teacher_Class_Assignments
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Teacher_Class_Assignments')
BEGIN
    CREATE TABLE Teacher_Class_Assignments (
        Academic_Year SMALLINT NOT NULL,
        Semester TINYINT NOT NULL,
        Teacher_Id INT NOT NULL,
        Class_Level TINYINT NOT NULL,
        class_Letter CHAR(1) NOT NULL,
        Subject_Id NVARCHAR(10) NOT NULL,
        Course_Level TINYINT NOT NULL,
        CONSTRAINT PK_Assignments PRIMARY KEY (
            Academic_Year, Semester, Teacher_Id,
            Class_Level, class_Letter, Subject_Id, Course_Level),
        CONSTRAINT FK_Fact_Teacher FOREIGN KEY (Teacher_Id)
            REFERENCES Teacher(Teacher_Id) ON UPDATE CASCADE,
        CONSTRAINT FK_Fact_Class FOREIGN KEY (Class_Level, class_Letter)
            REFERENCES class(Class_Level, class_Letter) ON UPDATE CASCADE,
        CONSTRAINT FK_Fact_Course FOREIGN KEY (Subject_Id, Course_Level)
            REFERENCES Courses(Subject_Id, Course_Level) ON UPDATE CASCADE
    );
END
GO

-- 11. Student_Grades   [2] now its own block
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Student_Grades')
BEGIN
    CREATE TABLE Student_Grades (
        Academic_Year SMALLINT NOT NULL,
        Semester TINYINT NOT NULL,
        Student_Id INT NOT NULL,
        Subject_Id NVARCHAR(10) NOT NULL,
        Course_Level TINYINT NOT NULL,
        First_Grade  INT CHECK (First_Grade  >= 0 AND First_Grade  <= 100),
        Second_Grade INT CHECK (Second_Grade >= 0 AND Second_Grade <= 100),
        third_Grade  INT CHECK (third_Grade  >= 0 AND third_Grade  <= 100),
        Final_Grade  INT CHECK (Final_Grade  >= 0 AND Final_Grade  <= 100),
        CONSTRAINT PK_Student_Grades PRIMARY KEY (
            Academic_Year, Semester, Student_Id, Subject_Id, Course_Level),
        CONSTRAINT FK_Student_Grades FOREIGN KEY (Student_Id)
            REFERENCES Student(Student_Id) ON UPDATE CASCADE,
        CONSTRAINT FK_Course_Grades FOREIGN KEY (Subject_Id, Course_Level)
            REFERENCES Courses(Subject_Id, Course_Level) ON UPDATE CASCADE
    );
END
GO