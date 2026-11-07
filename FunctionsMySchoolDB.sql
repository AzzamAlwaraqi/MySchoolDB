USE MYSchoolDB
GO

-- 1. Overall average grade for one student (0–100)
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='FN' AND name='calculate_Student_Overall_Grade')
    DROP FUNCTION calculate_Student_Overall_Grade;
GO
CREATE FUNCTION calculate_Student_Overall_Grade(@Student_Id INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @Student_Overall_Grade FLOAT;
    -- Average of every mark entered so far. AVG skips NULLs, so a mark that isn't in yet
    -- doesn't count as 0, and the FLOAT cast stops integer division cutting off decimals.
    SELECT @Student_Overall_Grade = AVG(CAST(m.Mark AS FLOAT))
    FROM Student_Grades
    CROSS APPLY (VALUES (First_Grade), (Second_Grade), (third_Grade), (Final_Grade)) AS m(Mark)
    WHERE Student_Id = @Student_Id;
    RETURN @Student_Overall_Grade;
END;
GO

-- 2. Students in a governorate
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='FN' AND name='Student_Numbers_for_each_governate')
    DROP FUNCTION Student_Numbers_for_each_governate;
GO
CREATE FUNCTION Student_Numbers_for_each_governate(@GOV_ID INT)
RETURNS INT
AS
BEGIN
    DECLARE @n INT;
    SELECT @n = COUNT(DISTINCT Student_Addresses.Student_Id)
    FROM Student_Addresses
    INNER JOIN Address      ON Student_Addresses.Address_Id = Address.Address_Id
    INNER JOIN Governorates ON Governorates.Gov_Id = Address.Gov_Id
    WHERE Governorates.Gov_Id = @GOV_ID;
    RETURN @n;
END;
GO

-- 3. Teachers for a subject
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='FN' AND name='Number_of_Teachers_For_each_Subject')
    DROP FUNCTION Number_of_Teachers_For_each_Subject;
GO
CREATE FUNCTION Number_of_Teachers_For_each_Subject(@Subject_Id NVARCHAR(10))
RETURNS INT
AS
BEGIN
    DECLARE @n INT;
    SELECT @n = COUNT(DISTINCT Teacher_Id)
    FROM Teacher_Class_Assignments
    INNER JOIN Subjects ON Subjects.Subject_Id = Teacher_Class_Assignments.Subject_Id
    WHERE Subjects.Subject_Id = @Subject_Id;
    RETURN @n;
END;
GO

-- 4. Full detail rows for one student (inline TVF)
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='IF' AND name='Student_Details')
    DROP FUNCTION Student_Details;
GO
CREATE FUNCTION Student_Details(@Student_Id INT)
RETURNS TABLE
AS
RETURN (
    SELECT Student.Student_id, Student.First_Name AS SFN, Student.Last_Name AS SLN,
           Student.Class_Level, Student.class_Letter,
           Teacher.First_name, Teacher.Last_name,
           Subjects.Subject_Name_Ar, Subjects.Subject_Name_En,
           Student_Grades.First_Grade, Student_Grades.Second_Grade,
           Student_Grades.third_Grade, Student_Grades.Final_Grade,
          (SELECT CAST(AVG(CAST(m.Mark AS DECIMAL(5,2))) AS DECIMAL(5,2))
             FROM (VALUES (Student_Grades.First_Grade), (Student_Grades.Second_Grade),
                          (Student_Grades.third_Grade), (Student_Grades.Final_Grade)) AS m(Mark))
              AS Student_Avg_Grade   -- marks entered so far, with decimals
    FROM Student_Grades
    INNER JOIN Student ON Student.Student_Id = Student_Grades.Student_Id
    INNER JOIN Teacher_Class_Assignments
        ON Teacher_Class_Assignments.Class_Level  = Student.Class_Level
       AND Teacher_Class_Assignments.class_Letter = Student.class_Letter
       AND Teacher_Class_Assignments.Subject_Id   = Student_Grades.Subject_Id
       AND Teacher_Class_Assignments.Course_Level = Student_Grades.Course_Level   -- added
    INNER JOIN Teacher  ON Teacher.Teacher_Id  = Teacher_Class_Assignments.Teacher_Id
    INNER JOIN Subjects ON Subjects.Subject_Id = Student_Grades.Subject_Id
    WHERE Student.Student_id = @Student_Id
);
GO

-- 5. Top-three students in a class (inline TVF)
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='IF' AND name='First_three_student_in_each_class')
    DROP FUNCTION First_three_student_in_each_class;
GO
CREATE FUNCTION First_three_student_in_each_class(@Class_Level TINYINT, @class_letter CHAR(1))
RETURNS TABLE
AS
RETURN (
    SELECT * FROM (
        SELECT Student.Student_id, Student.First_Name, Student.Last_Name,
               Student.Class_level, Student.class_Letter,
               dbo.calculate_Student_Overall_Grade(Student.Student_id) AS student_Overall_mark,
               DENSE_RANK() OVER (
                   PARTITION BY Student.Class_Level, Student.class_Letter
                   ORDER BY dbo.calculate_Student_Overall_Grade(Student.Student_id) DESC
               ) AS Student_rank
        FROM Student
        INNER JOIN class
            ON Student.Class_level  = class.Class_Level
           AND Student.class_Letter = class.class_Letter
        WHERE class.Class_Level = @Class_Level AND class.class_Letter = @class_letter
    ) AS Ranked
    WHERE Student_rank <= 3        -- top three (was unfiltered)
);
GO

-- quick tests
SELECT dbo.calculate_Student_Overall_Grade(2026101)    AS Student_Overall_Grade;
SELECT dbo.Student_Numbers_for_each_governate(1)       AS Students_in_Amman;
SELECT dbo.Number_of_Teachers_For_each_Subject('MATH') AS Teachers_for_MATH;
SELECT * FROM dbo.Student_Details(2026101);
SELECT * FROM dbo.First_three_student_in_each_class(1, 'A');