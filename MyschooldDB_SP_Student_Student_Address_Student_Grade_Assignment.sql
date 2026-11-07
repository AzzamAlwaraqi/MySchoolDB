USE MYSchoolDB;
GO
-- ============================================================ Student_SP
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='Student_SP')
    DROP PROCEDURE Student_SP;
GO
CREATE PROCEDURE Student_SP
    @Student_Id         INT           = NULL,
    @First_Name         NVARCHAR(30)  = NULL,
    @Last_Name          NVARCHAR(30)  = NULL,
    @Date_of_Birth      DATE          = NULL,
    @Gender             CHAR(1)       = NULL,
    @Blood_Type         VARCHAR(5)    = NULL,
    @Medical_Conditions NVARCHAR(MAX) = NULL,    
    @Class_Level        TINYINT       = NULL,
    @class_Letter       CHAR(1)       = NULL,
    @Parental_Id        INT           = NULL,
    @Operation_Type     INT,
    @Result_Message     VARCHAR(200) OUTPUT,
    @Error_Message      VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op NVARCHAR(20) = N'Unknown', @key NVARCHAR(100) = CAST(@Student_Id AS NVARCHAR(100));
    SET @Error_Message = NULL;

    IF @Operation_Type NOT IN (1,2,3,4,5)
    BEGIN
        SET @Result_Message='Operation failed.'; SET @Error_Message='Invalid Operation_Type (1=Save,2=Delete,3=Search,4=ReportCard,5=Profile).';
        EXEC usp_WriteLog N'Student', N'Invalid', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
    END

    BEGIN TRY
        IF @Operation_Type = 1
        BEGIN
            IF EXISTS (SELECT 1 FROM Student WHERE Student_Id=@Student_Id)
            BEGIN
                UPDATE Student
                   SET First_Name         = COALESCE(@First_Name, First_Name),
                       Last_Name          = COALESCE(@Last_Name, Last_Name),
                       Date_of_Birth      = COALESCE(@Date_of_Birth, Date_of_Birth),
                       Gender             = COALESCE(@Gender, Gender),
                       Blood_Type         = COALESCE(@Blood_Type, Blood_Type),
                       Medical_Conditions = COALESCE(@Medical_Conditions, Medical_Conditions),
                       Class_Level        = COALESCE(@Class_Level, Class_Level),
                       class_Letter       = COALESCE(@class_Letter, class_Letter),
                       Parental_Id        = COALESCE(@Parental_Id, Parental_Id)
                 WHERE Student_Id=@Student_Id;
                SET @op=N'Save (Update)'; SET @Result_Message='Student updated successfully.';
            END
            ELSE
            BEGIN
                IF @Student_Id IS NULL OR @First_Name IS NULL OR @Last_Name IS NULL
                   OR @Date_of_Birth IS NULL OR @Gender IS NULL
                   OR @Class_Level IS NULL OR @class_Letter IS NULL OR @Parental_Id IS NULL
                BEGIN
                    SET @Result_Message='Operation failed.'; SET @Error_Message='Student_Id, names, DOB, Gender, class and Parental_Id are required for a new student.';
                    EXEC usp_WriteLog N'Student', N'Save', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
                END
                IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id=@Parental_Id)
                BEGIN
                    SET @Result_Message='Operation failed.'; SET @Error_Message='Parent (Parental_Id) does not exist.';
                    EXEC usp_WriteLog N'Student', N'Save', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
                END
                IF NOT EXISTS (SELECT 1 FROM class WHERE Class_Level=@Class_Level AND class_Letter=@class_Letter)
                BEGIN
                    SET @Result_Message='Operation failed.'; SET @Error_Message='Target class (Class_Level + class_Letter) does not exist.';
                    EXEC usp_WriteLog N'Student', N'Save', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
                END
                INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id)
                VALUES (@Student_Id, @First_Name, @Last_Name, @Date_of_Birth, @Gender, @Blood_Type, @Medical_Conditions, @Class_Level, @class_Letter, @Parental_Id);
                SET @op=N'Save (Insert)'; SET @Result_Message='Student inserted successfully.';
            END
        END
        ELSE IF @Operation_Type = 2   -- DELETE (block-on-delete policy)
        BEGIN
            SET @op=N'Delete';
            IF @Student_Id IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Student_Id is required for delete.';
                EXEC usp_WriteLog N'Student', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id=@Student_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='No student found with that Student_Id.';
                EXEC usp_WriteLog N'Student', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF EXISTS (SELECT 1 FROM Student_Grades WHERE Student_Id=@Student_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Cannot delete: this student has grade records. Remove the grades first.';
                EXEC usp_WriteLog N'Student', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            DELETE FROM Student WHERE Student_Id=@Student_Id;  -- Student_Addresses links cascade away
            SET @Result_Message='Student deleted successfully.';
        END
        ELSE IF @Operation_Type = 3
        BEGIN
            SET @op=N'Search';
            SELECT Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type,
                   Medical_Conditions, Class_Level, class_Letter, Parental_Id
              FROM Student
             WHERE (@Student_Id   IS NULL OR Student_Id = @Student_Id)
               AND (@First_Name   IS NULL OR First_Name LIKE N'%'+@First_Name+N'%')
               AND (@Last_Name    IS NULL OR Last_Name  LIKE N'%'+@Last_Name+N'%')
               AND (@Gender       IS NULL OR Gender = @Gender)
               AND (@Class_Level  IS NULL OR Class_Level = @Class_Level)
               AND (@class_Letter IS NULL OR class_Letter = @class_Letter)
               AND (@Parental_Id  IS NULL OR Parental_Id = @Parental_Id)
             ORDER BY Class_Level, class_Letter, Last_Name;
            SET @Result_Message='Search completed.';
        END
        ELSE IF @Operation_Type = 4   -- REPORT CARD (master + detail)
        BEGIN
            SET @op=N'ReportCard';
            IF @Student_Id IS NULL OR NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id=@Student_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='A valid Student_Id is required for the report card.';
                EXEC usp_WriteLog N'Student', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            -- master: student + overall average + rank within class
            SELECT s.Student_Id, s.First_Name, s.Last_Name, s.Class_Level, s.class_Letter,
                   dbo.calculate_Student_Overall_Grade(s.Student_Id) AS Overall_Average,
                   (SELECT COUNT(*)+1 FROM Student s2
                     WHERE s2.Class_Level=s.Class_Level AND s2.class_Letter=s.class_Letter
                       AND dbo.calculate_Student_Overall_Grade(s2.Student_Id)
                         > dbo.calculate_Student_Overall_Grade(s.Student_Id)) AS Class_Rank
              FROM Student s WHERE s.Student_Id=@Student_Id;
            -- detail: per subject
            SELECT g.Subject_Id, sub.Subject_Name_Ar, sub.Subject_Name_En, g.Course_Level,
                   g.First_Grade, g.Second_Grade, g.third_Grade, g.Final_Grade,
                   CAST(g.First_Grade+g.Second_Grade+g.third_Grade+g.Final_Grade AS DECIMAL(6,2))/4 AS Subject_Avg
              FROM Student_Grades g
              JOIN Subjects sub ON sub.Subject_Id = g.Subject_Id
             WHERE g.Student_Id=@Student_Id
             ORDER BY g.Subject_Id;
            SET @Result_Message='Report card generated.';
        END
        ELSE IF @Operation_Type = 5   -- FULL PROFILE
        BEGIN
            SET @op=N'Profile';
            IF @Student_Id IS NULL OR NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id=@Student_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='A valid Student_Id is required for the profile.';
                EXEC usp_WriteLog N'Student', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            SELECT s.Student_Id, s.First_Name, s.Last_Name, s.Date_of_Birth, s.Gender,
                   s.Blood_Type, s.Medical_Conditions, s.Class_Level, s.class_Letter,
                   p.Parental_Id, p.First_name AS Parent_First, p.Last_name AS Parent_Last,
                   p.relationship, p.Phone_Number AS Parent_Phone,
                   g.Gov_Name_En AS Main_Governorate, a.District, a.Street, a.Building_No
              FROM Student s
              JOIN Parents p ON p.Parental_Id = s.Parental_Id
              LEFT JOIN Student_Addresses sa ON sa.Student_Id = s.Student_Id AND sa.Main_Address = 1
              LEFT JOIN Address a     ON a.Address_Id = sa.Address_Id
              LEFT JOIN Governorates g ON g.Gov_Id = a.Gov_Id
             WHERE s.Student_Id=@Student_Id;
            SET @Result_Message='Profile generated.';
        END

        EXEC usp_WriteLog N'Student', @op, @key, 'SUCCESS', @Result_Message, NULL;
    END TRY
    BEGIN CATCH
        SET @Result_Message='Operation failed (exception).'; SET @Error_Message=ERROR_MESSAGE();
        EXEC usp_WriteLog N'Student', @op, @key, 'FAILED', @Result_Message, @Error_Message;
    END CATCH
END
GO

-- ============================================================ StudentAddress_SP
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='StudentAddress_SP')
    DROP PROCEDURE StudentAddress_SP;
GO
CREATE PROCEDURE StudentAddress_SP
    @Student_Id     INT     = NULL,
    @Address_Id     INT     = NULL,
    @Main_Address   BIT     = NULL,
    @Operation_Type INT,
    @Result_Message VARCHAR(200) OUTPUT,
    @Error_Message  VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op NVARCHAR(20)=N'Unknown', @key NVARCHAR(100)=CONCAT(@Student_Id, N'/', @Address_Id);
    SET @Error_Message = NULL;

    IF @Operation_Type NOT IN (1,2,3,4)
    BEGIN
        SET @Result_Message='Operation failed.'; SET @Error_Message='Invalid Operation_Type (1=Link,2=Unlink,3=Search,4=SetMain).';
        EXEC usp_WriteLog N'Student_Addresses', N'Invalid', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
    END

    BEGIN TRY
        IF @Operation_Type = 1   -- link (or update the flag)
        BEGIN
            IF @Student_Id IS NULL OR @Address_Id IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Student_Id and Address_Id are required.';
                EXEC usp_WriteLog N'Student_Addresses', N'Link', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id=@Student_Id)
                OR NOT EXISTS (SELECT 1 FROM Address WHERE Address_Id=@Address_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Student or Address does not exist.';
                EXEC usp_WriteLog N'Student_Addresses', N'Link', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            BEGIN TRAN;
                IF EXISTS (SELECT 1 FROM Student_Addresses WHERE Student_Id=@Student_Id AND Address_Id=@Address_Id)
                BEGIN
                    UPDATE Student_Addresses SET Main_Address = COALESCE(@Main_Address, Main_Address)
                     WHERE Student_Id=@Student_Id AND Address_Id=@Address_Id;
                    SET @op=N'Link (Update)';
                END
                ELSE
                BEGIN
                    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address)
                    VALUES (@Student_Id, @Address_Id, COALESCE(@Main_Address, 0));
                    SET @op=N'Link (Insert)';
                END
                IF @Main_Address = 1
                    UPDATE Student_Addresses SET Main_Address = 0
                     WHERE Student_Id=@Student_Id AND Address_Id <> @Address_Id;
            COMMIT;
            SET @Result_Message='Address linked to student.';
        END
        ELSE IF @Operation_Type = 2   -- unlink
        BEGIN
            SET @op=N'Unlink';
            IF @Student_Id IS NULL OR @Address_Id IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Student_Id and Address_Id are required.';
                EXEC usp_WriteLog N'Student_Addresses', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF NOT EXISTS (SELECT 1 FROM Student_Addresses WHERE Student_Id=@Student_Id AND Address_Id=@Address_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='No such student-address link.';
                EXEC usp_WriteLog N'Student_Addresses', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            DELETE FROM Student_Addresses WHERE Student_Id=@Student_Id AND Address_Id=@Address_Id;
            SET @Result_Message='Address unlinked from student.';
        END
        ELSE IF @Operation_Type = 3   -- search by student or address
        BEGIN
            SET @op=N'Search';
            SELECT sa.Student_Id, st.First_Name, st.Last_Name,
                   sa.Address_Id, a.District, a.Street, a.Building_No, sa.Main_Address
              FROM Student_Addresses sa
              JOIN Student st ON st.Student_Id = sa.Student_Id
              JOIN Address a  ON a.Address_Id  = sa.Address_Id
             WHERE (@Student_Id IS NULL OR sa.Student_Id = @Student_Id)
               AND (@Address_Id IS NULL OR sa.Address_Id = @Address_Id)
             ORDER BY sa.Student_Id, sa.Main_Address DESC;
            SET @Result_Message='Search completed.';
        END
        ELSE IF @Operation_Type = 4   -- set main address
        BEGIN
            SET @op=N'SetMain';
            IF @Student_Id IS NULL OR @Address_Id IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Student_Id and Address_Id are required for SetMain.';
                EXEC usp_WriteLog N'Student_Addresses', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF NOT EXISTS (SELECT 1 FROM Student_Addresses WHERE Student_Id=@Student_Id AND Address_Id=@Address_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='That address is not linked to the student.';
                EXEC usp_WriteLog N'Student_Addresses', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            BEGIN TRAN;
                UPDATE Student_Addresses SET Main_Address = 0 WHERE Student_Id=@Student_Id;
                UPDATE Student_Addresses SET Main_Address = 1 WHERE Student_Id=@Student_Id AND Address_Id=@Address_Id;
            COMMIT;
            SET @Result_Message='Main address updated.';
        END

        EXEC usp_WriteLog N'Student_Addresses', @op, @key, 'SUCCESS', @Result_Message, NULL;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Result_Message='Operation failed (exception).'; SET @Error_Message=ERROR_MESSAGE();
        EXEC usp_WriteLog N'Student_Addresses', @op, @key, 'FAILED', @Result_Message, @Error_Message;
    END CATCH
END
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='Assignment_SP')
    DROP PROCEDURE Assignment_SP;
GO
CREATE PROCEDURE Assignment_SP
    @Academic_Year  SMALLINT     = NULL,
    @Semester       TINYINT      = NULL,
    @Teacher_Id     INT          = NULL,
    @Class_Level    TINYINT      = NULL,
    @class_Letter   CHAR(1)      = NULL,
    @Subject_Id     NVARCHAR(10) = NULL,
    @Course_Level   TINYINT      = NULL,
    @Operation_Type INT,
    @Result_Message VARCHAR(200) OUTPUT,
    @Error_Message  VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op NVARCHAR(20)=N'Unknown',
            @key NVARCHAR(100)=CONCAT(@Academic_Year,N'/',@Semester,N'/T',@Teacher_Id,N'/',@Class_Level,@class_Letter,N'/',@Subject_Id);
    SET @Error_Message = NULL;

    IF @Operation_Type NOT IN (1,2,3,4)
    BEGIN
        SET @Result_Message='Operation failed.'; SET @Error_Message='Invalid Operation_Type (1=Save,2=Delete,3=Search,4=ClassTimetable).';
        EXEC usp_WriteLog N'Teacher_Class_Assignments', N'Invalid', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
    END

    BEGIN TRY
        IF @Operation_Type = 1   -- insert (all columns are key; nothing to update)
        BEGIN
            SET @op=N'Save';
            IF @Academic_Year IS NULL OR @Semester IS NULL OR @Teacher_Id IS NULL OR @Class_Level IS NULL
               OR @class_Letter IS NULL OR @Subject_Id IS NULL OR @Course_Level IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='All seven key fields are required for an assignment.';
                EXEC usp_WriteLog N'Teacher_Class_Assignments', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF EXISTS (SELECT 1 FROM Teacher_Class_Assignments
                        WHERE Academic_Year=@Academic_Year AND Semester=@Semester AND Teacher_Id=@Teacher_Id
                          AND Class_Level=@Class_Level AND class_Letter=@class_Letter
                          AND Subject_Id=@Subject_Id AND Course_Level=@Course_Level)
            BEGIN
                SET @Result_Message='This assignment already exists.';
                EXEC usp_WriteLog N'Teacher_Class_Assignments', @op, @key, 'SUCCESS', @Result_Message, NULL; RETURN;
            END
            IF NOT EXISTS (SELECT 1 FROM Teacher WHERE Teacher_Id=@Teacher_Id)
            BEGIN SET @Result_Message='Operation failed.'; SET @Error_Message='Teacher does not exist.';
                  EXEC usp_WriteLog N'Teacher_Class_Assignments', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN; END
            IF NOT EXISTS (SELECT 1 FROM class WHERE Class_Level=@Class_Level AND class_Letter=@class_Letter)
            BEGIN SET @Result_Message='Operation failed.'; SET @Error_Message='Class does not exist.';
                  EXEC usp_WriteLog N'Teacher_Class_Assignments', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN; END
            IF NOT EXISTS (SELECT 1 FROM Courses WHERE Subject_Id=@Subject_Id AND Course_Level=@Course_Level)
            BEGIN SET @Result_Message='Operation failed.'; SET @Error_Message='Course (Subject_Id + Course_Level) does not exist.';
                  EXEC usp_WriteLog N'Teacher_Class_Assignments', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN; END

            INSERT INTO Teacher_Class_Assignments
                (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level)
            VALUES (@Academic_Year, @Semester, @Teacher_Id, @Class_Level, @class_Letter, @Subject_Id, @Course_Level);
            SET @Result_Message='Assignment created successfully.';
        END
        ELSE IF @Operation_Type = 2   -- delete one exact assignment
        BEGIN
            SET @op=N'Delete';
            IF @Academic_Year IS NULL OR @Semester IS NULL OR @Teacher_Id IS NULL OR @Class_Level IS NULL
               OR @class_Letter IS NULL OR @Subject_Id IS NULL OR @Course_Level IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='All seven key fields are required to delete a specific assignment.';
                EXEC usp_WriteLog N'Teacher_Class_Assignments', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF NOT EXISTS (SELECT 1 FROM Teacher_Class_Assignments
                            WHERE Academic_Year=@Academic_Year AND Semester=@Semester AND Teacher_Id=@Teacher_Id
                              AND Class_Level=@Class_Level AND class_Letter=@class_Letter
                              AND Subject_Id=@Subject_Id AND Course_Level=@Course_Level)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='No matching assignment found.';
                EXEC usp_WriteLog N'Teacher_Class_Assignments', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            DELETE FROM Teacher_Class_Assignments
             WHERE Academic_Year=@Academic_Year AND Semester=@Semester AND Teacher_Id=@Teacher_Id
               AND Class_Level=@Class_Level AND class_Letter=@class_Letter
               AND Subject_Id=@Subject_Id AND Course_Level=@Course_Level;
            SET @Result_Message='Assignment deleted successfully.';
        END
        ELSE IF @Operation_Type = 3   -- flexible search
        BEGIN
            SET @op=N'Search';
            SELECT a.Academic_Year, a.Semester, a.Teacher_Id, t.First_name, t.Last_name,
                   a.Class_Level, a.class_Letter, a.Subject_Id, a.Course_Level
              FROM Teacher_Class_Assignments a
              JOIN Teacher t ON t.Teacher_Id = a.Teacher_Id
             WHERE (@Academic_Year IS NULL OR a.Academic_Year = @Academic_Year)
               AND (@Semester      IS NULL OR a.Semester = @Semester)
               AND (@Teacher_Id    IS NULL OR a.Teacher_Id = @Teacher_Id)
               AND (@Class_Level   IS NULL OR a.Class_Level = @Class_Level)
               AND (@class_Letter  IS NULL OR a.class_Letter = @class_Letter)
               AND (@Subject_Id    IS NULL OR a.Subject_Id = @Subject_Id)
             ORDER BY a.Academic_Year, a.Semester, a.Class_Level, a.class_Letter;
            SET @Result_Message='Search completed.';
        END
        ELSE IF @Operation_Type = 4   -- class timetable
        BEGIN
            SET @op=N'ClassTimetable';
            IF @Class_Level IS NULL OR @class_Letter IS NULL OR @Academic_Year IS NULL OR @Semester IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Academic_Year, Semester, Class_Level and class_Letter are required.';
                EXEC usp_WriteLog N'Teacher_Class_Assignments', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            SELECT a.Subject_Id, s.Subject_Name_En, a.Course_Level,
                   a.Teacher_Id, t.First_name, t.Last_name
              FROM Teacher_Class_Assignments a
              JOIN Subjects s ON s.Subject_Id = a.Subject_Id
              JOIN Teacher  t ON t.Teacher_Id = a.Teacher_Id
             WHERE a.Academic_Year=@Academic_Year AND a.Semester=@Semester
               AND a.Class_Level=@Class_Level AND a.class_Letter=@class_Letter
             ORDER BY s.Subject_Name_En;
            SET @Result_Message='Class timetable listed.';
        END

        EXEC usp_WriteLog N'Teacher_Class_Assignments', @op, @key, 'SUCCESS', @Result_Message, NULL;
    END TRY
    BEGIN CATCH
        SET @Result_Message='Operation failed (exception).'; SET @Error_Message=ERROR_MESSAGE();
        EXEC usp_WriteLog N'Teacher_Class_Assignments', @op, @key, 'FAILED', @Result_Message, @Error_Message;
    END CATCH
END
GO

-- ============================================================ StudentGrade_SP
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='StudentGrade_SP')
    DROP PROCEDURE StudentGrade_SP;
GO
CREATE PROCEDURE StudentGrade_SP
    @Academic_Year  SMALLINT     = NULL,
    @Semester       TINYINT      = NULL,
    @Student_Id     INT          = NULL,
    @Subject_Id     NVARCHAR(10) = NULL,
    @Course_Level   TINYINT      = NULL,
    @First_Grade    INT          = NULL,
    @Second_Grade   INT          = NULL,
    @third_Grade    INT          = NULL,
    @Final_Grade    INT          = NULL,
    @Operation_Type INT,
    @Result_Message VARCHAR(200) OUTPUT,
    @Error_Message  VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op NVARCHAR(20)=N'Unknown',
            @key NVARCHAR(100)=CONCAT(@Academic_Year,N'/',@Semester,N'/S',@Student_Id,N'/',@Subject_Id,N'-L',@Course_Level);
    SET @Error_Message = NULL;

    IF @Operation_Type NOT IN (1,2,3,4)
    BEGIN
        SET @Result_Message='Operation failed.'; SET @Error_Message='Invalid Operation_Type (1=Save,2=Delete,3=Search,4=SemesterAverages).';
        EXEC usp_WriteLog N'Student_Grades', N'Invalid', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
    END

    BEGIN TRY
        IF @Operation_Type = 1   -- insert or update grades
        BEGIN
            IF @Academic_Year IS NULL OR @Semester IS NULL OR @Student_Id IS NULL
               OR @Subject_Id IS NULL OR @Course_Level IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Year, Semester, Student_Id, Subject_Id and Course_Level are required.';
                EXEC usp_WriteLog N'Student_Grades', N'Save', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF EXISTS (SELECT 1 FROM Student_Grades
                        WHERE Academic_Year=@Academic_Year AND Semester=@Semester AND Student_Id=@Student_Id
                          AND Subject_Id=@Subject_Id AND Course_Level=@Course_Level)
            BEGIN
                UPDATE Student_Grades
                   SET First_Grade  = COALESCE(@First_Grade,  First_Grade),
                       Second_Grade = COALESCE(@Second_Grade, Second_Grade),
                       third_Grade  = COALESCE(@third_Grade,  third_Grade),
                       Final_Grade  = COALESCE(@Final_Grade,  Final_Grade)
                 WHERE Academic_Year=@Academic_Year AND Semester=@Semester AND Student_Id=@Student_Id
                   AND Subject_Id=@Subject_Id AND Course_Level=@Course_Level;
                SET @op=N'Save (Update)'; SET @Result_Message='Grades updated successfully.';
            END
            ELSE
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id=@Student_Id)
                BEGIN SET @Result_Message='Operation failed.'; SET @Error_Message='Student does not exist.';
                      EXEC usp_WriteLog N'Student_Grades', N'Save', @key, 'FAILED', @Result_Message, @Error_Message; RETURN; END
                IF NOT EXISTS (SELECT 1 FROM Courses WHERE Subject_Id=@Subject_Id AND Course_Level=@Course_Level)
                BEGIN SET @Result_Message='Operation failed.'; SET @Error_Message='Course (Subject_Id + Course_Level) does not exist.';
                      EXEC usp_WriteLog N'Student_Grades', N'Save', @key, 'FAILED', @Result_Message, @Error_Message; RETURN; END
                INSERT INTO Student_Grades
                    (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade)
                VALUES (@Academic_Year, @Semester, @Student_Id, @Subject_Id, @Course_Level, @First_Grade, @Second_Grade, @third_Grade, @Final_Grade);
                SET @op=N'Save (Insert)'; SET @Result_Message='Grades inserted successfully.';
            END
        END
        ELSE IF @Operation_Type = 2   -- delete a grade record
        BEGIN
            SET @op=N'Delete';
            IF @Academic_Year IS NULL OR @Semester IS NULL OR @Student_Id IS NULL
               OR @Subject_Id IS NULL OR @Course_Level IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Full key is required to delete a grade record.';
                EXEC usp_WriteLog N'Student_Grades', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF NOT EXISTS (SELECT 1 FROM Student_Grades
                            WHERE Academic_Year=@Academic_Year AND Semester=@Semester AND Student_Id=@Student_Id
                              AND Subject_Id=@Subject_Id AND Course_Level=@Course_Level)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='No matching grade record found.';
                EXEC usp_WriteLog N'Student_Grades', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            DELETE FROM Student_Grades
             WHERE Academic_Year=@Academic_Year AND Semester=@Semester AND Student_Id=@Student_Id
               AND Subject_Id=@Subject_Id AND Course_Level=@Course_Level;
            SET @Result_Message='Grade record deleted successfully.';
        END
        ELSE IF @Operation_Type = 3   -- search
        BEGIN
            SET @op=N'Search';
            SELECT g.Academic_Year, g.Semester, g.Student_Id, st.First_Name, st.Last_Name,
                   g.Subject_Id, g.Course_Level, g.First_Grade, g.Second_Grade, g.third_Grade, g.Final_Grade,
                   CAST((g.First_Grade+g.Second_Grade+g.third_Grade+g.Final_Grade) AS DECIMAL(6,2))/4 AS Subject_Avg
              FROM Student_Grades g
              JOIN Student st ON st.Student_Id = g.Student_Id
             WHERE (@Academic_Year IS NULL OR g.Academic_Year = @Academic_Year)
               AND (@Semester      IS NULL OR g.Semester = @Semester)
               AND (@Student_Id    IS NULL OR g.Student_Id = @Student_Id)
               AND (@Subject_Id    IS NULL OR g.Subject_Id = @Subject_Id)
               AND (@Course_Level  IS NULL OR g.Course_Level = @Course_Level)
             ORDER BY g.Student_Id, g.Subject_Id;
            SET @Result_Message='Search completed.';
        END
        ELSE IF @Operation_Type = 4   -- semester averages for a student
        BEGIN
            SET @op=N'SemesterAverages';
            IF @Student_Id IS NULL OR @Academic_Year IS NULL OR @Semester IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Student_Id, Academic_Year and Semester are required.';
                EXEC usp_WriteLog N'Student_Grades', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            SELECT g.Subject_Id, sub.Subject_Name_En,
                   CAST((g.First_Grade+g.Second_Grade+g.third_Grade+g.Final_Grade) AS DECIMAL(6,2))/4 AS Subject_Avg
              FROM Student_Grades g
              JOIN Subjects sub ON sub.Subject_Id = g.Subject_Id
             WHERE g.Student_Id=@Student_Id AND g.Academic_Year=@Academic_Year AND g.Semester=@Semester
             ORDER BY g.Subject_Id;
            -- brackets matter: without them only Final_Grade was divided by 4
            SELECT AVG(CAST((First_Grade+Second_Grade+third_Grade+Final_Grade) AS DECIMAL(6,2))/4) AS Overall_Semester_Average
              FROM Student_Grades
             WHERE Student_Id=@Student_Id AND Academic_Year=@Academic_Year AND Semester=@Semester;
            SET @Result_Message='Semester averages generated.';
        END

        EXEC usp_WriteLog N'Student_Grades', @op, @key, 'SUCCESS', @Result_Message, NULL;
    END TRY
    BEGIN CATCH
        SET @Result_Message='Operation failed (exception).'; SET @Error_Message=ERROR_MESSAGE();
        EXEC usp_WriteLog N'Student_Grades', @op, @key, 'FAILED', @Result_Message, @Error_Message;
    END CATCH
END
GO