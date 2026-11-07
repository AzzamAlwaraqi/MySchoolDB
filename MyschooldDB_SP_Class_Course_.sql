USE MYSchoolDB;
GO
-- ============================================================ Class_SP
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='Class_SP')
    DROP PROCEDURE Class_SP;
GO
CREATE PROCEDURE Class_SP
    @class_Letter     CHAR(1)      = NULL,
    @Student_Capacity TINYINT      = NULL,
    @Class_Level      TINYINT      = NULL,
    @Room_Number      VARCHAR(20)  = NULL,
    @Operation_Type   INT,
    @Result_Message   VARCHAR(200) OUTPUT,
    @Error_Message    VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op NVARCHAR(20) = N'Unknown', @key NVARCHAR(100) = CONCAT(@Class_Level, N'-', @class_Letter);
    SET @Error_Message = NULL;

    IF @Operation_Type NOT IN (1,2,3,4,5)
    BEGIN
        SET @Result_Message='Operation failed.'; SET @Error_Message='Invalid Operation_Type (1=Save,2=Delete,3=Search,4=Roster,5=Availability).';
        EXEC usp_WriteLog N'class', N'Invalid', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
    END

    BEGIN TRY
        IF @Operation_Type = 1
        BEGIN
            IF EXISTS (SELECT 1 FROM class WHERE Class_Level=@Class_Level AND class_Letter=@class_Letter)
            BEGIN
                UPDATE class
                   SET Student_Capacity = COALESCE(@Student_Capacity, Student_Capacity),
                       Room_Number      = COALESCE(@Room_Number, Room_Number)
                 WHERE Class_Level=@Class_Level AND class_Letter=@class_Letter;
                SET @op=N'Save (Update)'; SET @Result_Message='Class updated successfully.';
            END
            ELSE
            BEGIN
                IF @Class_Level IS NULL OR @class_Letter IS NULL OR @Student_Capacity IS NULL OR @Room_Number IS NULL
                BEGIN
                    SET @Result_Message='Operation failed.'; SET @Error_Message='Class_Level, class_Letter, Student_Capacity and Room_Number are required for a new class.';
                    EXEC usp_WriteLog N'class', N'Save', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
                END
                INSERT INTO class (class_Letter, Student_Capacity, Class_Level, Room_Number)
                VALUES (@class_Letter, @Student_Capacity, @Class_Level, @Room_Number);
                SET @op=N'Save (Insert)'; SET @Result_Message='Class inserted successfully.';
            END
        END
        ELSE IF @Operation_Type = 2
        BEGIN
            SET @op=N'Delete';
            IF @Class_Level IS NULL OR @class_Letter IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Class_Level and class_Letter are required for delete.';
                EXEC usp_WriteLog N'class', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF NOT EXISTS (SELECT 1 FROM class WHERE Class_Level=@Class_Level AND class_Letter=@class_Letter)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='No class found with that level and letter.';
                EXEC usp_WriteLog N'class', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF EXISTS (SELECT 1 FROM Student WHERE Class_Level=@Class_Level AND class_Letter=@class_Letter)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Cannot delete: students are enrolled in this class.';
                EXEC usp_WriteLog N'class', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Class_Level=@Class_Level AND class_Letter=@class_Letter)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Cannot delete: teacher assignments exist for this class.';
                EXEC usp_WriteLog N'class', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            DELETE FROM class WHERE Class_Level=@Class_Level AND class_Letter=@class_Letter;
            SET @Result_Message='Class deleted successfully.';
        END
        ELSE IF @Operation_Type = 3
        BEGIN
            SET @op=N'Search';
            SELECT class_Letter, Student_Capacity, Class_Level, Room_Number
              FROM class
             WHERE (@Class_Level      IS NULL OR Class_Level = @Class_Level)
               AND (@class_Letter     IS NULL OR class_Letter = @class_Letter)
               AND (@Student_Capacity IS NULL OR Student_Capacity = @Student_Capacity)
               AND (@Room_Number      IS NULL OR Room_Number = @Room_Number)
             ORDER BY Class_Level, class_Letter;
            SET @Result_Message='Search completed.';
        END
        ELSE IF @Operation_Type = 4   -- roster
        BEGIN
            SET @op=N'Roster';
            IF @Class_Level IS NULL OR @class_Letter IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Class_Level and class_Letter are required for the roster.';
                EXEC usp_WriteLog N'class', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            SELECT Student_Id, First_Name, Last_Name, Gender, Date_of_Birth
              FROM Student
             WHERE Class_Level=@Class_Level AND class_Letter=@class_Letter
             ORDER BY Last_Name, First_Name;
            SET @Result_Message='Class roster listed.';
        END
        ELSE IF @Operation_Type = 5   -- availability / seats
        BEGIN
            SET @op=N'Availability';
            IF @Class_Level IS NULL OR @class_Letter IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Class_Level and class_Letter are required for availability.';
                EXEC usp_WriteLog N'class', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            SELECT c.Class_Level, c.class_Letter, c.Room_Number, c.Student_Capacity,
                   COUNT(s.Student_Id) AS Current_Enrollment,
                   c.Student_Capacity - COUNT(s.Student_Id) AS Remaining_Seats
              FROM class c
              LEFT JOIN Student s ON s.Class_Level=c.Class_Level AND s.class_Letter=c.class_Letter
             WHERE c.Class_Level=@Class_Level AND c.class_Letter=@class_Letter
             GROUP BY c.Class_Level, c.class_Letter, c.Room_Number, c.Student_Capacity;
            SET @Result_Message='Class availability listed.';
        END

        EXEC usp_WriteLog N'class', @op, @key, 'SUCCESS', @Result_Message, NULL;
    END TRY
    BEGIN CATCH
        SET @Result_Message='Operation failed (exception).'; SET @Error_Message=ERROR_MESSAGE();
        EXEC usp_WriteLog N'class', @op, @key, 'FAILED', @Result_Message, @Error_Message;
    END CATCH
END
GO

-- ============================================================ Course_SP
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='Course_SP')
    DROP PROCEDURE Course_SP;
GO
CREATE PROCEDURE Course_SP
    @Subject_Id         NVARCHAR(10)  = NULL,
    @Learning_Materials NVARCHAR(MAX) = NULL,
    @Description        NVARCHAR(MAX) = NULL,
    @Course_Level       TINYINT       = NULL,
    @Operation_Type     INT,
    @Result_Message     VARCHAR(200) OUTPUT,
    @Error_Message      VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op NVARCHAR(20) = N'Unknown', @key NVARCHAR(100) = CONCAT(@Subject_Id, N'-L', @Course_Level);
    SET @Error_Message = NULL;

    IF @Operation_Type NOT IN (1,2,3,4,5)
    BEGIN
        SET @Result_Message='Operation failed.'; SET @Error_Message='Invalid Operation_Type (1=Save,2=Delete,3=Search,4=Teachers,5=Students).';
        EXEC usp_WriteLog N'Courses', N'Invalid', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
    END

    BEGIN TRY
        IF @Operation_Type = 1
        BEGIN
            IF EXISTS (SELECT 1 FROM Courses WHERE Subject_Id=@Subject_Id AND Course_Level=@Course_Level)
            BEGIN
                UPDATE Courses
                   SET Learning_Materials = COALESCE(@Learning_Materials, Learning_Materials),
                       [Description]      = COALESCE(@Description, [Description])
                 WHERE Subject_Id=@Subject_Id AND Course_Level=@Course_Level;
                SET @op=N'Save (Update)'; SET @Result_Message='Course updated successfully.';
            END
            ELSE
            BEGIN
                IF @Subject_Id IS NULL OR @Course_Level IS NULL OR @Learning_Materials IS NULL OR @Description IS NULL
                BEGIN
                    SET @Result_Message='Operation failed.'; SET @Error_Message='Subject_Id, Course_Level, Learning_Materials and Description are required for a new course.';
                    EXEC usp_WriteLog N'Courses', N'Save', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
                END
                IF NOT EXISTS (SELECT 1 FROM Subjects WHERE Subject_Id=@Subject_Id)
                BEGIN
                    SET @Result_Message='Operation failed.'; SET @Error_Message='Parent subject does not exist. Create the subject first.';
                    EXEC usp_WriteLog N'Courses', N'Save', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
                END
                INSERT INTO Courses (Subject_Id, Learning_Materials, [Description], Course_Level)
                VALUES (@Subject_Id, @Learning_Materials, @Description, @Course_Level);
                SET @op=N'Save (Insert)'; SET @Result_Message='Course inserted successfully.';
            END
        END
        ELSE IF @Operation_Type = 2
        BEGIN
            SET @op=N'Delete';
            IF @Subject_Id IS NULL OR @Course_Level IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Subject_Id and Course_Level are required for delete.';
                EXEC usp_WriteLog N'Courses', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF NOT EXISTS (SELECT 1 FROM Courses WHERE Subject_Id=@Subject_Id AND Course_Level=@Course_Level)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='No course found with that Subject_Id and Course_Level.';
                EXEC usp_WriteLog N'Courses', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Subject_Id=@Subject_Id AND Course_Level=@Course_Level)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Cannot delete: this course is assigned to teachers.';
                EXEC usp_WriteLog N'Courses', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF EXISTS (SELECT 1 FROM Student_Grades WHERE Subject_Id=@Subject_Id AND Course_Level=@Course_Level)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Cannot delete: grades exist for this course.';
                EXEC usp_WriteLog N'Courses', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            DELETE FROM Courses WHERE Subject_Id=@Subject_Id AND Course_Level=@Course_Level;
            SET @Result_Message='Course deleted successfully.';
        END
        ELSE IF @Operation_Type = 3
        BEGIN
            SET @op=N'Search';
            SELECT Subject_Id, Course_Level, Learning_Materials, [Description]
              FROM Courses
             WHERE (@Subject_Id         IS NULL OR Subject_Id = @Subject_Id)
               AND (@Course_Level       IS NULL OR Course_Level = @Course_Level)
               AND (@Learning_Materials IS NULL OR Learning_Materials LIKE N'%'+@Learning_Materials+N'%')
               AND (@Description        IS NULL OR [Description] LIKE N'%'+@Description+N'%')
             ORDER BY Subject_Id, Course_Level;
            SET @Result_Message='Search completed.';
        END
        ELSE IF @Operation_Type = 4   -- teachers of this course
        BEGIN
            SET @op=N'Teachers';
            IF @Subject_Id IS NULL OR @Course_Level IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Subject_Id and Course_Level are required.';
                EXEC usp_WriteLog N'Courses', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            SELECT DISTINCT t.Teacher_Id, t.First_name, t.Last_name,
                   a.Class_Level, a.class_Letter, a.Academic_Year, a.Semester
              FROM Teacher_Class_Assignments a
              JOIN Teacher t ON t.Teacher_Id = a.Teacher_Id
             WHERE a.Subject_Id=@Subject_Id AND a.Course_Level=@Course_Level
             ORDER BY t.Last_name, a.Class_Level;
            SET @Result_Message='Teachers for this course listed.';
        END
        ELSE IF @Operation_Type = 5   -- students graded in this course
        BEGIN
            SET @op=N'Students';
            IF @Subject_Id IS NULL OR @Course_Level IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Subject_Id and Course_Level are required.';
                EXEC usp_WriteLog N'Courses', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            SELECT g.Student_Id, st.First_Name, st.Last_Name, st.Class_Level, st.class_Letter,
                   g.First_Grade, g.Second_Grade, g.third_Grade, g.Final_Grade,
                   CAST(g.First_Grade+g.Second_Grade+g.third_Grade+g.Final_Grade AS DECIMAL(6,2))/4 AS Subject_Avg
              FROM Student_Grades g
              JOIN Student st ON st.Student_Id = g.Student_Id
             WHERE g.Subject_Id=@Subject_Id AND g.Course_Level=@Course_Level
             ORDER BY Subject_Avg DESC;
            SET @Result_Message='Students graded in this course listed.';
        END

        EXEC usp_WriteLog N'Courses', @op, @key, 'SUCCESS', @Result_Message, NULL;
    END TRY
    BEGIN CATCH
        SET @Result_Message='Operation failed (exception).'; SET @Error_Message=ERROR_MESSAGE();
        EXEC usp_WriteLog N'Courses', @op, @key, 'FAILED', @Result_Message, @Error_Message;
    END CATCH
END
GO