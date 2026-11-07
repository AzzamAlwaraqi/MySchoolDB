USE MYSchoolDB;
GO

-- Trace log (datetime + audit trail) ------------------------------------
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Operation_Log')
BEGIN
    CREATE TABLE Operation_Log (
        Log_Id         INT IDENTITY(1,1) PRIMARY KEY,
        Log_DateTime   DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
        Table_Name     NVARCHAR(50)  NOT NULL,
        Operation_Type NVARCHAR(20)  NOT NULL,   -- 'Save (Insert)','Delete','Search',...
        Record_Key     NVARCHAR(100) NULL,       -- affected PK value(s) as text
        Status         VARCHAR(10)   NOT NULL,   -- 'SUCCESS' / 'FAILED'
        Result_Message VARCHAR(200)  NULL,
        Error_Message  VARCHAR(200)  NULL,
        Performed_By   NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME()
    );
END
GO

-- Reusable logging helper -----------------------------------------------
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='usp_WriteLog')
    DROP PROCEDURE usp_WriteLog;
GO
CREATE PROCEDURE usp_WriteLog
    @Table  NVARCHAR(50),
    @Op     NVARCHAR(20),
    @Key    NVARCHAR(100),
    @Status VARCHAR(10),
    @Result VARCHAR(200),
    @Error  VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Operation_Log (Table_Name, Operation_Type, Record_Key, Status, Result_Message, Error_Message)
    VALUES (@Table, @Op, @Key, @Status, @Result, @Error);
END
GO










USE MYSchoolDB;
GO
-- ============================================================ 
--Subject_SP
-- =============================================================

IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='Subject_SP')
    DROP PROCEDURE Subject_SP;
GO
CREATE PROCEDURE Subject_SP
    @Subject_Id      NVARCHAR(10) = NULL,
    @Subject_Name_Ar NVARCHAR(50) = NULL,
    @Subject_Name_En VARCHAR(50)  = NULL,
    @Required_Level  TINYINT      = NULL,
    @Filter_Level    TINYINT      = NULL,        
    @Operation_Type  INT,
    @Result_Message  VARCHAR(200) OUTPUT,
    @Error_Message   VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op NVARCHAR(20) = N'Unknown', @key NVARCHAR(100) = @Subject_Id;
    SET @Error_Message = NULL;

    IF @Operation_Type NOT IN (1,2,3,4)
    BEGIN
        SET @Result_Message = 'Operation failed.';
        SET @Error_Message  = 'Invalid Operation_Type (1=Save, 2=Delete, 3=Search, 4=AvailableByLevel).';
        EXEC usp_WriteLog N'Subjects', N'Invalid', @key, 'FAILED', @Result_Message, @Error_Message;
        RETURN;
    END

    BEGIN TRY
    -------------------------------------------------------------------------
        -- 1: SAVE (insert if new, partial update if exists) 
    --------------------------------------------------------------------------
        IF @Operation_Type = 1
        BEGIN
            IF EXISTS (SELECT 1 FROM Subjects WHERE Subject_Id = @Subject_Id)
            BEGIN
                UPDATE Subjects
                   SET Subject_Name_Ar = COALESCE(@Subject_Name_Ar, Subject_Name_Ar),
                       Subject_Name_En = COALESCE(@Subject_Name_En, Subject_Name_En),
                       Required_Level  = COALESCE(@Required_Level,  Required_Level)
                 WHERE Subject_Id = @Subject_Id;
                SET @op = N'Save (Update)';  SET @Result_Message = 'Subject updated successfully.';
            END
            ELSE
            BEGIN
                IF @Subject_Id IS NULL OR @Subject_Name_Ar IS NULL
                   OR @Subject_Name_En IS NULL OR @Required_Level IS NULL
                BEGIN
                    SET @Result_Message = 'Operation failed.';
                    SET @Error_Message  = 'Subject_Id, Arabic/English names and Required_Level are required for a new subject.';
                    EXEC usp_WriteLog N'Subjects', N'Save', @key, 'FAILED', @Result_Message, @Error_Message;
                    RETURN;
                END
                INSERT INTO Subjects (Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level)
                VALUES (@Subject_Id, @Subject_Name_Ar, @Subject_Name_En, @Required_Level);
                SET @op = N'Save (Insert)';  SET @Result_Message = 'Subject inserted successfully.';
            END
        END
        ---------------------------------------------------------------------
        -- 2: DELETE (blocked if courses reference it)
        ------------------------------------------------------------------------
        ELSE IF @Operation_Type = 2
        BEGIN
            SET @op = N'Delete';
            IF @Subject_Id IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Subject_Id is required for delete.';
                EXEC usp_WriteLog N'Subjects', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF NOT EXISTS (SELECT 1 FROM Subjects WHERE Subject_Id = @Subject_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='No subject found with that Subject_Id.';
                EXEC usp_WriteLog N'Subjects', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF EXISTS (SELECT 1 FROM Courses WHERE Subject_Id = @Subject_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Cannot delete: this subject still has courses. Remove them first.';
                EXEC usp_WriteLog N'Subjects', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            DELETE FROM Subjects WHERE Subject_Id = @Subject_Id;
            SET @Result_Message = 'Subject deleted successfully.';
        END
        --------------------------------------------------------------------
        -- 3: SEARCH (optional filters) ------------------------------------
        ---------------------------------------------------------------------
        ELSE IF @Operation_Type = 3
        BEGIN
            SET @op = N'Search';
            SELECT Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level
              FROM Subjects
             WHERE (@Subject_Id      IS NULL OR Subject_Id = @Subject_Id)
               AND (@Subject_Name_Ar IS NULL OR Subject_Name_Ar LIKE N'%' + @Subject_Name_Ar + N'%')
               AND (@Subject_Name_En IS NULL OR Subject_Name_En LIKE   '%' + @Subject_Name_En +   '%')
               AND (@Required_Level  IS NULL OR Required_Level = @Required_Level);
            SET @Result_Message = 'Search completed.';
        END
        ---------------------------------------------------------------------
        -- 4: UNIQUE — subjects allowed at a class level
        ----------------------------------------------------------------------
        ELSE IF @Operation_Type = 4
        BEGIN
            SET @op = N'AvailableByLevel';
            IF @Filter_Level IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='@Filter_Level is required for AvailableByLevel.';
                EXEC usp_WriteLog N'Subjects', @op, NULL, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            SELECT Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level
              FROM Subjects WHERE Required_Level <= @Filter_Level
             ORDER BY Required_Level, Subject_Name_En;
            SET @Result_Message = 'Subjects available at level ' + CAST(@Filter_Level AS VARCHAR(3)) + ' listed.';
        END

        EXEC usp_WriteLog N'Subjects', @op, @key, 'SUCCESS', @Result_Message, NULL;
    END TRY
    BEGIN CATCH
        SET @Result_Message = 'Operation failed (exception).';
        SET @Error_Message  = ERROR_MESSAGE();
        EXEC usp_WriteLog N'Subjects', @op, @key, 'FAILED', @Result_Message, @Error_Message;
        -- To surface the error to the application layer instead, add:  THROW;
    END CATCH
END
GO

-- ============================================================ 
--  Parent_SP
-- ============================================================

IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='Parent_SP')
    DROP PROCEDURE Parent_SP;
GO
CREATE PROCEDURE Parent_SP
    @Parental_Id  INT          = NULL,
    @First_name   NVARCHAR(30) = NULL,
    @Last_name    NVARCHAR(30) = NULL,
    @Email        VARCHAR(100) = NULL,
    @Phone_Number VARCHAR(20)  = NULL,
    @relationship NVARCHAR(30) = NULL,
    @Occupation   NVARCHAR(50) = NULL,
    @Operation_Type INT,
    @Result_Message VARCHAR(200) OUTPUT,
    @Error_Message  VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op NVARCHAR(20) = N'Unknown', @key NVARCHAR(100) = CAST(@Parental_Id AS NVARCHAR(100));
    SET @Error_Message = NULL;

    IF @Operation_Type NOT IN (1,2,3,4)
    BEGIN
        SET @Result_Message='Operation failed.'; SET @Error_Message='Invalid Operation_Type (1=Save,2=Delete,3=Search,4=GetChildren).';
        EXEC usp_WriteLog N'Parents', N'Invalid', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
    END

    BEGIN TRY
        IF @Operation_Type = 1
        BEGIN
            IF EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = @Parental_Id)
            BEGIN
                UPDATE Parents
                   SET First_name   = COALESCE(@First_name,   First_name),
                       Last_name    = COALESCE(@Last_name,    Last_name),
                       Email        = COALESCE(@Email,        Email),
                       Phone_Number = COALESCE(@Phone_Number, Phone_Number),
                       relationship = COALESCE(@relationship, relationship),
                       Occupation   = COALESCE(@Occupation,   Occupation)
                 WHERE Parental_Id = @Parental_Id;
                SET @op=N'Save (Update)'; SET @Result_Message='Parent updated successfully.';
            END
            ELSE
            BEGIN
                IF @Parental_Id IS NULL OR @First_name IS NULL OR @Last_name IS NULL
                   OR @Email IS NULL OR @Phone_Number IS NULL OR @relationship IS NULL OR @Occupation IS NULL
                BEGIN
                    SET @Result_Message='Operation failed.'; SET @Error_Message='All parent fields are required for a new parent.';
                    EXEC usp_WriteLog N'Parents', N'Save', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
                END
                INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation)
                VALUES (@Parental_Id, @First_name, @Last_name, @Email, @Phone_Number, @relationship, @Occupation);
                SET @op=N'Save (Insert)'; SET @Result_Message='Parent inserted successfully.';
            END
        END
        ELSE IF @Operation_Type = 2
        BEGIN
            SET @op = N'Delete';
            IF @Parental_Id IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Parental_Id is required for delete.';
                EXEC usp_WriteLog N'Parents', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = @Parental_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='No parent found with that Parental_Id.';
                EXEC usp_WriteLog N'Parents', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF EXISTS (SELECT 1 FROM Student WHERE Parental_Id = @Parental_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Cannot delete: this parent still has students linked to them.';
                EXEC usp_WriteLog N'Parents', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            DELETE FROM Parents WHERE Parental_Id = @Parental_Id;
            SET @Result_Message='Parent deleted successfully.';
        END
        ELSE IF @Operation_Type = 3
        BEGIN
            SET @op = N'Search';
            SELECT Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation
              FROM Parents
             WHERE (@Parental_Id  IS NULL OR Parental_Id = @Parental_Id)
               AND (@First_name   IS NULL OR First_name  LIKE N'%'+@First_name+N'%')
               AND (@Last_name    IS NULL OR Last_name   LIKE N'%'+@Last_name+N'%')
               AND (@Email        IS NULL OR Email = @Email)
               AND (@Phone_Number IS NULL OR Phone_Number = @Phone_Number)
               AND (@Occupation   IS NULL OR Occupation LIKE N'%'+@Occupation+N'%');
            SET @Result_Message='Search completed.';
        END
        ELSE IF @Operation_Type = 4   -- children of this parent
        BEGIN
            SET @op = N'GetChildren';
            IF @Parental_Id IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Parental_Id is required for GetChildren.';
                EXEC usp_WriteLog N'Parents', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            SELECT Student_Id, First_Name, Last_Name, Class_Level, class_Letter, Date_of_Birth
              FROM Student WHERE Parental_Id = @Parental_Id
             ORDER BY Class_Level, class_Letter, Last_Name;
            SET @Result_Message='Children listed.';
        END

        EXEC usp_WriteLog N'Parents', @op, @key, 'SUCCESS', @Result_Message, NULL;
    END TRY
    BEGIN CATCH
        SET @Result_Message='Operation failed (exception).'; SET @Error_Message=ERROR_MESSAGE();
        EXEC usp_WriteLog N'Parents', @op, @key, 'FAILED', @Result_Message, @Error_Message;
    END CATCH
END
GO

-- ============================================================ Teacher_SP
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='Teacher_SP')
    DROP PROCEDURE Teacher_SP;
GO
CREATE PROCEDURE Teacher_SP
    @Teacher_Id     INT          = NULL,
    @First_name     NVARCHAR(30) = NULL,
    @Last_name      NVARCHAR(30) = NULL,
    @Email          VARCHAR(50)  = NULL,
    @Phone_Number   VARCHAR(20)  = NULL,
    @hire_date      DATE         = NULL,
    @specialization NVARCHAR(100)= NULL,
    @is_full_time   BIT          = NULL,
    @qualification  NVARCHAR(50) = NULL,
    @Operation_Type INT,
    @Result_Message VARCHAR(200) OUTPUT,
    @Error_Message  VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op NVARCHAR(20) = N'Unknown', @key NVARCHAR(100) = CAST(@Teacher_Id AS NVARCHAR(100));
    SET @Error_Message = NULL;

    IF @Operation_Type NOT IN (1,2,3,4)
    BEGIN
        SET @Result_Message='Operation failed.'; SET @Error_Message='Invalid Operation_Type (1=Save,2=Delete,3=Search,4=GetSchedule).';
        EXEC usp_WriteLog N'Teacher', N'Invalid', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
    END

    BEGIN TRY
        IF @Operation_Type = 1
        BEGIN
            IF EXISTS (SELECT 1 FROM Teacher WHERE Teacher_Id = @Teacher_Id)
            BEGIN
                UPDATE Teacher
                   SET First_name     = COALESCE(@First_name,     First_name),
                       Last_name      = COALESCE(@Last_name,      Last_name),
                       Email          = COALESCE(@Email,          Email),
                       Phone_Number   = COALESCE(@Phone_Number,   Phone_Number),
                       hire_date      = COALESCE(@hire_date,      hire_date),
                       specialization = COALESCE(@specialization, specialization),
                       is_full_time   = COALESCE(@is_full_time,   is_full_time),
                       qualification  = COALESCE(@qualification,  qualification)
                 WHERE Teacher_Id = @Teacher_Id;
                SET @op=N'Save (Update)'; SET @Result_Message='Teacher updated successfully.';
            END
            ELSE
            BEGIN
                IF @Teacher_Id IS NULL OR @First_name IS NULL OR @Last_name IS NULL
                   OR @Email IS NULL OR @Phone_Number IS NULL OR @qualification IS NULL
                BEGIN
                    SET @Result_Message='Operation failed.'; SET @Error_Message='Teacher_Id, names, Email, Phone and qualification are required for a new teacher.';
                    EXEC usp_WriteLog N'Teacher', N'Save', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
                END
                INSERT INTO Teacher (Teacher_Id, First_name, Last_name, Email, Phone_Number, hire_date, specialization, is_full_time, qualification)
                VALUES (@Teacher_Id, @First_name, @Last_name, @Email, @Phone_Number,
                        COALESCE(@hire_date, CAST(SYSDATETIME() AS DATE)),
                        @specialization, COALESCE(@is_full_time, 1), @qualification);
                SET @op=N'Save (Insert)'; SET @Result_Message='Teacher inserted successfully.';
            END
        END
        ELSE IF @Operation_Type = 2
        BEGIN
            SET @op = N'Delete';
            IF @Teacher_Id IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Teacher_Id is required for delete.';
                EXEC usp_WriteLog N'Teacher', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF NOT EXISTS (SELECT 1 FROM Teacher WHERE Teacher_Id = @Teacher_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='No teacher found with that Teacher_Id.';
                EXEC usp_WriteLog N'Teacher', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Teacher_Id = @Teacher_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Cannot delete: this teacher still has class assignments.';
                EXEC usp_WriteLog N'Teacher', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            DELETE FROM Teacher WHERE Teacher_Id = @Teacher_Id;
            SET @Result_Message='Teacher deleted successfully.';
        END
        ELSE IF @Operation_Type = 3
        BEGIN
            SET @op = N'Search';
            SELECT Teacher_Id, First_name, Last_name, Email, Phone_Number, hire_date, specialization, is_full_time, qualification
              FROM Teacher
             WHERE (@Teacher_Id     IS NULL OR Teacher_Id = @Teacher_Id)
               AND (@First_name     IS NULL OR First_name LIKE N'%'+@First_name+N'%')
               AND (@Last_name      IS NULL OR Last_name  LIKE N'%'+@Last_name+N'%')
               AND (@Email          IS NULL OR Email = @Email)
               AND (@Phone_Number   IS NULL OR Phone_Number = @Phone_Number)
               AND (@specialization IS NULL OR specialization LIKE N'%'+@specialization+N'%')
               AND (@is_full_time   IS NULL OR is_full_time = @is_full_time)
               AND (@qualification  IS NULL OR qualification LIKE N'%'+@qualification+N'%');
            SET @Result_Message='Search completed.';
        END
        ELSE IF @Operation_Type = 4   -- teaching schedule
        BEGIN
            SET @op = N'GetSchedule';
            IF @Teacher_Id IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Teacher_Id is required for GetSchedule.';
                EXEC usp_WriteLog N'Teacher', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            SELECT a.Academic_Year, a.Semester, a.Class_Level, a.class_Letter,
                   a.Subject_Id, s.Subject_Name_En, a.Course_Level
              FROM Teacher_Class_Assignments a
              JOIN Subjects s ON s.Subject_Id = a.Subject_Id
             WHERE a.Teacher_Id = @Teacher_Id
             ORDER BY a.Academic_Year, a.Semester, a.Class_Level, a.class_Letter;
            SET @Result_Message='Teaching schedule listed.';
        END

        EXEC usp_WriteLog N'Teacher', @op, @key, 'SUCCESS', @Result_Message, NULL;
    END TRY
    BEGIN CATCH
        SET @Result_Message='Operation failed (exception).'; SET @Error_Message=ERROR_MESSAGE();
        EXEC usp_WriteLog N'Teacher', @op, @key, 'FAILED', @Result_Message, @Error_Message;
    END CATCH
END
GO
