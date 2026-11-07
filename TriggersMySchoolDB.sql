USE MYSchoolDB;
GO
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Data_Audit')
BEGIN
    CREATE TABLE Data_Audit (
        Audit_Id       INT IDENTITY(1,1) PRIMARY KEY,
        Audit_DateTime DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
        Table_Name     NVARCHAR(50)  NOT NULL,
        Action_Type    VARCHAR(10)   NOT NULL,   -- INSERT / UPDATE / DELETE
        Record_Key     NVARCHAR(200) NULL,
        Column_Name    NVARCHAR(50)  NULL,
        Old_Value      NVARCHAR(200) NULL,
        New_Value      NVARCHAR(200) NULL,
        Changed_By     NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME()
    );
END

GO

-- 1) Capacity check : a class may never exceed its Student_Capacity
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='TR' AND name='trg_Student_CapacityChecker')
    DROP TRIGGER trg_Student_CapacityChecker;
GO
CREATE TRIGGER trg_Student_CapacityChecker
ON Student
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM class c
        JOIN (SELECT DISTINCT Class_Level, class_Letter FROM inserted) i
          ON i.Class_Level = c.Class_Level AND i.class_Letter = c.class_Letter
        WHERE (SELECT COUNT(*) FROM Student s
                WHERE s.Class_Level = c.Class_Level AND s.class_Letter = c.class_Letter) > c.Student_Capacity
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50001, 'Class capacity exceeded: this would put the class over its Student_Capacity.', 1;
    END
END
GO

-- 2) Level match: a grade's Course_Level must equal the student's Class_Level
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='TR' AND name='trg_StudentGrades_LevelMatch')
    DROP TRIGGER trg_StudentGrades_LevelMatch;
GO
CREATE TRIGGER trg_StudentGrades_LevelMatch
ON Student_Grades
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN Student s ON s.Student_Id = i.Student_Id
        WHERE i.Course_Level <> s.Class_Level
        -- To allow multi-year history later, add:  AND i.Academic_Year = YEAR(GETDATE())
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50002, 'Level mismatch: a grade''s Course_Level must equal the student''s Class_Level.', 1;
    END
END
GO

-- 3) Required-level Checker: a course can't be assigned below its subject's Required_Level
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='TR' AND name='trg_Assignment_RequiredLevel')
    DROP TRIGGER trg_Assignment_RequiredLevel;
GO
CREATE TRIGGER trg_Assignment_RequiredLevel
ON Teacher_Class_Assignments
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN Subjects s ON s.Subject_Id = i.Subject_Id
        WHERE i.Course_Level < s.Required_Level
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50003, 'Required-level violation: course level is below the subject''s minimum Required_Level.', 1;
    END
END

GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='TR' AND name='trg_StudentGrades_Audit')
    DROP TRIGGER trg_StudentGrades_Audit;
GO
CREATE TRIGGER trg_StudentGrades_Audit
ON Student_Grades
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- UPDATE: one audit row per changed grade column
    IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO Data_Audit (Table_Name, Action_Type, Record_Key, Column_Name, Old_Value, New_Value)
        SELECT 'Student_Grades', 'UPDATE',
               CONCAT(d.Academic_Year,'/',d.Semester,'/S',d.Student_Id,'/',d.Subject_Id,'-L',d.Course_Level),
               col.Column_Name, col.Old_Value, col.New_Value
        FROM deleted d
        JOIN inserted i
          ON i.Academic_Year=d.Academic_Year AND i.Semester=d.Semester
         AND i.Student_Id=d.Student_Id AND i.Subject_Id=d.Subject_Id AND i.Course_Level=d.Course_Level
        CROSS APPLY (VALUES
            ('First_Grade',  CAST(d.First_Grade  AS NVARCHAR(200)), CAST(i.First_Grade  AS NVARCHAR(200))),
            ('Second_Grade', CAST(d.Second_Grade AS NVARCHAR(200)), CAST(i.Second_Grade AS NVARCHAR(200))),
            ('third_Grade',  CAST(d.third_Grade  AS NVARCHAR(200)), CAST(i.third_Grade  AS NVARCHAR(200))),
            ('Final_Grade',  CAST(d.Final_Grade  AS NVARCHAR(200)), CAST(i.Final_Grade  AS NVARCHAR(200)))
        ) AS col(Column_Name, Old_Value, New_Value)
        WHERE ISNULL(col.Old_Value,'') <> ISNULL(col.New_Value,'');
    END
    ELSE  -- DELETE: snapshot of the removed row
    BEGIN
        INSERT INTO Data_Audit (Table_Name, Action_Type, Record_Key, Column_Name, Old_Value, New_Value)
        SELECT 'Student_Grades', 'DELETE',
               CONCAT(d.Academic_Year,'/',d.Semester,'/S',d.Student_Id,'/',d.Subject_Id,'-L',d.Course_Level),
               'AllGrades',
               CONCAT('1st=',d.First_Grade,' 2nd=',d.Second_Grade,' 3rd=',d.third_Grade,' Final=',d.Final_Grade),
               NULL
        FROM deleted d;
    END
END
GO