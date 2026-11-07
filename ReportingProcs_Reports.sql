-- Dataset procs for the paginated reports in Reports\. Same rule as the other rpt_ procs:
-- one result set, input params only, no OUTPUT, no logging - just shaped data for SSRS.
USE MYSchoolDB;
GO

-- Subjects the student takes (through their class's teacher assignments) + who teaches each.
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='rpt_StudentSchedule')
    DROP PROCEDURE rpt_StudentSchedule;
GO
CREATE PROCEDURE rpt_StudentSchedule
    @Student_Id    INT,
    @Academic_Year SMALLINT = NULL,
    @Semester      TINYINT  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        a.Academic_Year,
        a.Semester,
        a.Subject_Id,
        sub.Subject_Name_Ar,
        sub.Subject_Name_En,
        a.Course_Level,
        t.Teacher_Id,
        t.First_name + N' ' + t.Last_name AS Teacher_Name,
        CAST(a.Class_Level AS NVARCHAR(3)) + N'-' + a.class_Letter AS Class_Name
    FROM Student s
    JOIN Teacher_Class_Assignments a
         ON a.Class_Level = s.Class_Level AND a.class_Letter = s.class_Letter
    JOIN Subjects sub ON sub.Subject_Id = a.Subject_Id
    JOIN Teacher  t   ON t.Teacher_Id  = a.Teacher_Id
    WHERE s.Student_Id = @Student_Id
      AND (@Academic_Year IS NULL OR a.Academic_Year = @Academic_Year)
      AND (@Semester      IS NULL OR a.Semester      = @Semester)
    ORDER BY a.Academic_Year, a.Semester, sub.Subject_Name_En;
END
GO

-- One-row student profile: personal info + parent + class + GPA + class rank.
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='rpt_StudentDetails')
    DROP PROCEDURE rpt_StudentDetails;
GO
CREATE PROCEDURE rpt_StudentDetails
    @Student_Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        s.Student_Id,
        s.First_Name,
        s.Last_Name,
        s.Date_of_Birth,
        DATEDIFF(YEAR, s.Date_of_Birth, GETDATE())
            - CASE WHEN MONTH(s.Date_of_Birth)*100 + DAY(s.Date_of_Birth)
                        > MONTH(GETDATE())*100 + DAY(GETDATE()) THEN 1 ELSE 0 END AS Age,
        s.Gender,
        s.Blood_Type,
        s.Medical_Conditions,
        CAST(s.Class_Level AS NVARCHAR(3)) + N'-' + s.class_Letter AS Class_Name,
        p.Parental_Id,
        p.First_name + N' ' + p.Last_name AS Parent_Name,
        p.relationship,
        p.Phone_Number AS Parent_Phone,
        p.Email        AS Parent_Email,
        p.Occupation,
        CAST(dbo.calculate_Student_Overall_Grade(s.Student_Id) AS DECIMAL(6,2)) AS GPA,
        (SELECT COUNT(*) + 1
           FROM Student s2
          WHERE s2.Class_Level  = s.Class_Level
            AND s2.class_Letter = s.class_Letter
            AND dbo.calculate_Student_Overall_Grade(s2.Student_Id)
                > dbo.calculate_Student_Overall_Grade(s.Student_Id)) AS Class_Rank
    FROM Student s
    JOIN Parents p ON p.Parental_Id = s.Parental_Id
    WHERE s.Student_Id = @Student_Id;
END
GO

-- All addresses on file for a student (main one first), resolved to governorate.
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='rpt_StudentAddress')
    DROP PROCEDURE rpt_StudentAddress;
GO
CREATE PROCEDURE rpt_StudentAddress
    @Student_Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        s.Student_Id,
        s.First_Name + N' ' + s.Last_Name AS Student_Name,
        sa.Address_Id,
        sa.Main_Address,
        a.Building_No,
        a.Street,
        a.District,
        g.Gov_Id,
        g.Gov_Name_Ar,
        g.Gov_Name_En
    FROM Student s
    JOIN Student_Addresses sa ON sa.Student_Id = s.Student_Id
    JOIN Address a            ON a.Address_Id  = sa.Address_Id
    JOIN Governorates g       ON g.Gov_Id      = a.Gov_Id
    WHERE s.Student_Id = @Student_Id
    ORDER BY sa.Main_Address DESC, g.Gov_Name_En;
END
GO

-- All students grouped by class, with GPA - feeds the collapsible "Students by Class" report.
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='rpt_StudentsByClass')
    DROP PROCEDURE rpt_StudentsByClass;
GO
CREATE PROCEDURE rpt_StudentsByClass
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(s.Class_Level AS NVARCHAR(3)) + N'-' + s.class_Letter AS Class_Name,
        s.Class_Level,
        s.class_Letter,
        s.Student_Id,
        s.First_Name + N' ' + s.Last_Name AS Student_Name,
        s.Gender,
        CAST(dbo.calculate_Student_Overall_Grade(s.Student_Id) AS DECIMAL(6,2)) AS GPA
    FROM Student s
    ORDER BY s.Class_Level, s.class_Letter, s.Last_Name, s.First_Name;
END
GO

-- The four procs below are used by the .rdl files but were only in the live database,
-- so a fresh install from these scripts couldn't run the reports.

-- Student picker for the report parameters: "2026101 - Name (1-A)".
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='rpt_StudentList')
    DROP PROCEDURE rpt_StudentList;
GO
CREATE PROCEDURE rpt_StudentList
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        s.Student_Id,
        CAST(s.Student_Id AS NVARCHAR(20)) + N' - ' + s.First_Name + N' ' + s.Last_Name
            + N' (' + CAST(s.Class_Level AS NVARCHAR(3)) + N'-' + s.class_Letter + N')' AS Display_Name
    FROM Student s
    ORDER BY s.Class_Level, s.class_Letter, s.Last_Name, s.First_Name;
END
GO

-- Teacher picker for the report parameters.
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='rpt_TeacherList')
    DROP PROCEDURE rpt_TeacherList;
GO
CREATE PROCEDURE rpt_TeacherList
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        t.Teacher_Id,
        CAST(t.Teacher_Id AS NVARCHAR(20)) + N' - ' + t.First_name + N' ' + t.Last_name AS Display_Name
    FROM Teacher t
    ORDER BY t.Last_name, t.First_name;
END
GO

-- Classes and subjects one teacher covers.
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='rpt_TeacherSchedule')
    DROP PROCEDURE rpt_TeacherSchedule;
GO
CREATE PROCEDURE rpt_TeacherSchedule
    @Teacher_Id    INT,
    @Academic_Year SMALLINT = NULL,
    @Semester      TINYINT  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        a.Academic_Year,
        a.Semester,
        a.Class_Level,
        a.class_Letter,
        a.Subject_Id,
        sub.Subject_Name_En,
        a.Course_Level
    FROM Teacher_Class_Assignments a
    JOIN Subjects sub ON sub.Subject_Id = a.Subject_Id
    WHERE a.Teacher_Id = @Teacher_Id
      AND (@Academic_Year IS NULL OR a.Academic_Year = @Academic_Year)
      AND (@Semester      IS NULL OR a.Semester      = @Semester)
    ORDER BY a.Academic_Year, a.Semester, a.Class_Level, a.class_Letter, sub.Subject_Name_En;
END
GO

-- One line per subject for the Student Marks report.
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='rpt_StudentReportCard_Lines')
    DROP PROCEDURE rpt_StudentReportCard_Lines;
GO
CREATE PROCEDURE rpt_StudentReportCard_Lines
    @Student_Id    INT,
    @Academic_Year SMALLINT = NULL,
    @Semester      TINYINT  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        g.Academic_Year,
        g.Semester,
        g.Subject_Id,
        sub.Subject_Name_Ar,
        sub.Subject_Name_En,
        g.Course_Level,
        g.First_Grade,
        g.Second_Grade,
        g.third_Grade,
        g.Final_Grade,
        (SELECT CAST(AVG(CAST(m.Mark AS DECIMAL(5,2))) AS DECIMAL(6,2))
           FROM (VALUES (g.First_Grade), (g.Second_Grade), (g.third_Grade), (g.Final_Grade)) AS m(Mark))
            AS Subject_Average   -- marks entered so far
    FROM Student_Grades g
    JOIN Subjects sub ON sub.Subject_Id = g.Subject_Id
    WHERE g.Student_Id = @Student_Id
      AND (@Academic_Year IS NULL OR g.Academic_Year = @Academic_Year)
      AND (@Semester      IS NULL OR g.Semester      = @Semester)
    ORDER BY g.Academic_Year, g.Semester, sub.Subject_Name_En;
END
GO
