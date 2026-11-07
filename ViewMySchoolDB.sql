USE MySchoolDB
GO

-- 1. All grade detail per student/subject
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='V' AND name='Student_All_Details')
    DROP VIEW Student_All_Details;
GO
CREATE VIEW Student_All_Details AS
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
   AND Teacher_Class_Assignments.Course_Level = Student_Grades.Course_Level
INNER JOIN Teacher  ON Teacher.Teacher_Id  = Teacher_Class_Assignments.Teacher_Id
INNER JOIN Subjects ON Subjects.Subject_Id = Student_Grades.Subject_Id;
GO

-- 2. Teachers per subject
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='V' AND name='Number_of_Teachers_each_Subject')
    DROP VIEW Number_of_Teachers_each_Subject;
GO
CREATE VIEW Number_of_Teachers_each_Subject AS
SELECT Subjects.Subject_Name_Ar, Subjects.Subject_Name_En,
       COUNT(DISTINCT Teacher_Class_Assignments.Teacher_Id) AS Number_of_Teachers
FROM Teacher_Class_Assignments
INNER JOIN Subjects ON Subjects.Subject_Id = Teacher_Class_Assignments.Subject_Id
GROUP BY Subjects.Subject_Name_Ar, Subjects.Subject_Name_En;
GO

-- 3. Students per governorate
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='V' AND name='Student_Numbers_each_governate')
    DROP VIEW Student_Numbers_each_governate;
GO
CREATE VIEW Student_Numbers_each_governate AS
SELECT Governorates.Gov_Name_Ar, Governorates.Gov_Name_En,
       COUNT(DISTINCT Student_Addresses.Student_Id) AS Number_of_Students
FROM Student_Addresses
INNER JOIN Address      ON Student_Addresses.Address_Id = Address.Address_Id
INNER JOIN Governorates ON Governorates.Gov_Id = Address.Gov_Id
GROUP BY Governorates.Gov_Name_Ar, Governorates.Gov_Name_En;
GO

-- 4. Student overall average (0–100)
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='V' AND name='Student_General_Grade')
    DROP VIEW Student_General_Grade;
GO
CREATE VIEW Student_General_Grade AS
-- Same rule as calculate_Student_Overall_Grade: average of the marks entered, with decimals
SELECT Student_Id,
       AVG(CAST(m.Mark AS FLOAT)) AS student_Avg_Grade
FROM Student_Grades
CROSS APPLY (VALUES (First_Grade), (Second_Grade), (third_Grade), (Final_Grade)) AS m(Mark)
GROUP BY Student_Id;
GO

-- 5. Top three students per class
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='V' AND name='Student_First_Three_for_each_class')
    DROP VIEW Student_First_Three_for_each_class;
GO
CREATE VIEW Student_First_Three_for_each_class AS
WITH Ranked AS (
    SELECT Student.Student_id, Student.First_Name, Student.Last_Name,
           Student.Class_Level, Student.class_Letter, Student_General_Grade.student_Avg_Grade,
           DENSE_RANK() OVER (
               PARTITION BY Student.Class_Level, Student.class_Letter
               ORDER BY Student_General_Grade.student_Avg_Grade DESC
           ) AS Student_rank
    FROM Student_General_Grade
    INNER JOIN Student ON Student.Student_Id = Student_General_Grade.Student_Id
)
SELECT Student_id, First_Name, Last_Name, Class_Level, class_Letter, student_Avg_Grade, Student_rank
FROM Ranked
WHERE Student_rank <= 3;          -- top three (was <= 2)
GO

-- quick checks
SELECT * FROM Student_General_Grade;
SELECT * FROM Student_Numbers_each_governate;
SELECT * FROM Number_of_Teachers_each_Subject;
SELECT * FROM Student_All_Details;
SELECT * FROM Student_First_Three_for_each_class;