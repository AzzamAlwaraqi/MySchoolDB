USE MYSchoolDB;
GO
-- ============================================================ Address_SP
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='Address_SP')
    DROP PROCEDURE Address_SP;
GO
CREATE PROCEDURE Address_SP
    @Address_Id     INT          = NULL,
    @Gov_Id         TINYINT      = NULL,
    @District       NVARCHAR(50) = NULL,
    @Street         NVARCHAR(50) = NULL,
    @Building_No    NVARCHAR(10) = NULL,    
    @Operation_Type INT,
    @Result_Message VARCHAR(200) OUTPUT,
    @Error_Message  VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op NVARCHAR(20) = N'Unknown', @key NVARCHAR(100) = CAST(@Address_Id AS NVARCHAR(100));
    DECLARE @existingId INT, @newId INT;
    SET @Error_Message = NULL;

    IF @Operation_Type NOT IN (1,2,3,4,5)
    BEGIN
        SET @Result_Message='Operation failed.'; SET @Error_Message='Invalid Operation_Type (1=Save,2=Delete,3=Search,4=ByGovernorate,5=Residents).';
        EXEC usp_WriteLog N'Address', N'Invalid', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
    END

    BEGIN TRY
        IF @Operation_Type = 1
        BEGIN
            -- update path: explicit, existing Address_Id
            IF @Address_Id IS NOT NULL AND EXISTS (SELECT 1 FROM Address WHERE Address_Id=@Address_Id)
            BEGIN
                UPDATE Address
                   SET Gov_Id      = COALESCE(@Gov_Id, Gov_Id),
                       District    = COALESCE(@District, District),
                       Street      = COALESCE(@Street, Street),
                       Building_No = COALESCE(@Building_No, Building_No)
                 WHERE Address_Id=@Address_Id;
                SET @op=N'Save (Update)'; SET @Result_Message='Address updated successfully.';
            END
            ELSE
            BEGIN
                IF @Gov_Id IS NULL OR @District IS NULL OR @Street IS NULL OR @Building_No IS NULL
                BEGIN
                    SET @Result_Message='Operation failed.'; SET @Error_Message='Gov_Id, District, Street and Building_No are required for a new address.';
                    EXEC usp_WriteLog N'Address', N'Save', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
                END
                IF NOT EXISTS (SELECT 1 FROM Governorates WHERE Gov_Id=@Gov_Id)
                BEGIN
                    SET @Result_Message='Operation failed.'; SET @Error_Message='No governorate exists with that Gov_Id.';
                    EXEC usp_WriteLog N'Address', N'Save', @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
                END
                -- de-duplicate: this physical location may already exist (UNIQUE constraint)
                SET @existingId = (SELECT Address_Id FROM Address
                                    WHERE Gov_Id=@Gov_Id AND District=@District AND Street=@Street AND Building_No=@Building_No);
                IF @existingId IS NOT NULL
                BEGIN
                    SET @op=N'Save (Exists)'; SET @key = CAST(@existingId AS NVARCHAR(100));
                    SET @Result_Message = 'Address already exists (Address_Id = ' + CAST(@existingId AS VARCHAR(10)) + ').';
                    SELECT @existingId AS Address_Id;
                END
                ELSE
                BEGIN
                    INSERT INTO Address (Gov_Id, District, Street, Building_No)
                    VALUES (@Gov_Id, @District, @Street, @Building_No);
                    SET @newId = CAST(SCOPE_IDENTITY() AS INT);
                    SET @key = CAST(@newId AS NVARCHAR(100));
                    SET @op=N'Save (Insert)'; SET @Result_Message='Address inserted (Address_Id = ' + CAST(@newId AS VARCHAR(10)) + ').';
                    SELECT @newId AS Address_Id;
                END
            END
        END
        ELSE IF @Operation_Type = 2
        BEGIN
            SET @op=N'Delete';
            IF @Address_Id IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Address_Id is required for delete.';
                EXEC usp_WriteLog N'Address', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF NOT EXISTS (SELECT 1 FROM Address WHERE Address_Id=@Address_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='No address found with that Address_Id.';
                EXEC usp_WriteLog N'Address', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            IF EXISTS (SELECT 1 FROM Student_Addresses WHERE Address_Id=@Address_Id)
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Cannot delete: students are linked to this address.';
                EXEC usp_WriteLog N'Address', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            DELETE FROM Address WHERE Address_Id=@Address_Id;
            SET @Result_Message='Address deleted successfully.';
        END
        ELSE IF @Operation_Type = 3
        BEGIN
            SET @op=N'Search';
            SELECT a.Address_Id, a.Gov_Id, g.Gov_Name_En, a.District, a.Street, a.Building_No
              FROM Address a
              JOIN Governorates g ON g.Gov_Id = a.Gov_Id
             WHERE (@Address_Id  IS NULL OR a.Address_Id = @Address_Id)
               AND (@Gov_Id      IS NULL OR a.Gov_Id = @Gov_Id)
               AND (@District    IS NULL OR a.District LIKE N'%'+@District+N'%')
               AND (@Street      IS NULL OR a.Street LIKE N'%'+@Street+N'%')
               AND (@Building_No IS NULL OR a.Building_No = @Building_No)
             ORDER BY a.Gov_Id, a.District, a.Street;
            SET @Result_Message='Search completed.';
        END
        ELSE IF @Operation_Type = 4   -- addresses in a governorate
        BEGIN
            SET @op=N'ByGovernorate';
            IF @Gov_Id IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Gov_Id is required for ByGovernorate.';
                EXEC usp_WriteLog N'Address', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            SELECT a.Address_Id, a.District, a.Street, a.Building_No, g.Gov_Name_Ar, g.Gov_Name_En
              FROM Address a
              JOIN Governorates g ON g.Gov_Id = a.Gov_Id
             WHERE a.Gov_Id = @Gov_Id
             ORDER BY a.District, a.Street;
            SET @Result_Message='Addresses in governorate listed.';
        END
        ELSE IF @Operation_Type = 5   -- residents at this address
        BEGIN
            SET @op=N'Residents';
            IF @Address_Id IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Address_Id is required for Residents.';
                EXEC usp_WriteLog N'Address', @op, @key, 'FAILED', @Result_Message, @Error_Message; RETURN;
            END
            SELECT sa.Student_Id, st.First_Name, st.Last_Name, st.Class_Level, st.class_Letter, sa.Main_Address
              FROM Student_Addresses sa
              JOIN Student st ON st.Student_Id = sa.Student_Id
             WHERE sa.Address_Id = @Address_Id
             ORDER BY sa.Main_Address DESC, st.Last_Name;
            SET @Result_Message='Residents at this address listed.';
        END

        EXEC usp_WriteLog N'Address', @op, @key, 'SUCCESS', @Result_Message, NULL;
    END TRY
    BEGIN CATCH
        SET @Result_Message='Operation failed (exception).'; SET @Error_Message=ERROR_MESSAGE();
        EXEC usp_WriteLog N'Address', @op, @key, 'FAILED', @Result_Message, @Error_Message;
    END CATCH
END
GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='Governorate_SP')
    DROP PROCEDURE Governorate_SP;
GO
CREATE PROCEDURE Governorate_SP
    @Gov_Id         TINYINT      = NULL,
    @Gov_Name_Ar    NVARCHAR(50) = NULL,
    @Gov_Name_En    VARCHAR(50)  = NULL,
    @Operation_Type INT,                       -- 3=Search, 4=StudentCount, 5=AllCounts
    @Result_Message VARCHAR(200) OUTPUT,
    @Error_Message  VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Error_Message = NULL;

    IF @Operation_Type NOT IN (3,4,5)
    BEGIN
        SET @Result_Message='Operation failed.';
        SET @Error_Message='Governorates are fixed reference data. Allowed: 3=Search, 4=StudentCount, 5=AllCounts.';
        RETURN;
    END

    BEGIN TRY
        IF @Operation_Type = 3
        BEGIN
            SELECT Gov_Id, Gov_Name_Ar, Gov_Name_En
              FROM Governorates
             WHERE (@Gov_Id      IS NULL OR Gov_Id = @Gov_Id)
               AND (@Gov_Name_Ar IS NULL OR Gov_Name_Ar LIKE N'%'+@Gov_Name_Ar+N'%')
               AND (@Gov_Name_En IS NULL OR Gov_Name_En LIKE   '%'+@Gov_Name_En+  '%')
             ORDER BY Gov_Id;
            SET @Result_Message='Search completed.';
        END
        ELSE IF @Operation_Type = 4
        BEGIN
            IF @Gov_Id IS NULL
            BEGIN
                SET @Result_Message='Operation failed.'; SET @Error_Message='Gov_Id is required for StudentCount.';
                RETURN;
            END
            SELECT g.Gov_Id, g.Gov_Name_Ar, g.Gov_Name_En,
                   COUNT(DISTINCT sa.Student_Id) AS Number_of_Students
              FROM Governorates g
              LEFT JOIN Address a            ON a.Gov_Id = g.Gov_Id
              LEFT JOIN Student_Addresses sa ON sa.Address_Id = a.Address_Id
             WHERE g.Gov_Id = @Gov_Id
             GROUP BY g.Gov_Id, g.Gov_Name_Ar, g.Gov_Name_En;
            SET @Result_Message='Student count listed.';
        END
        ELSE IF @Operation_Type = 5
        BEGIN
            SELECT g.Gov_Id, g.Gov_Name_Ar, g.Gov_Name_En,
                   COUNT(DISTINCT sa.Student_Id) AS Number_of_Students
              FROM Governorates g
              LEFT JOIN Address a            ON a.Gov_Id = g.Gov_Id
              LEFT JOIN Student_Addresses sa ON sa.Address_Id = a.Address_Id
             GROUP BY g.Gov_Id, g.Gov_Name_Ar, g.Gov_Name_En
             ORDER BY Number_of_Students DESC, g.Gov_Name_En;
            SET @Result_Message='Student counts for all governorates listed.';
        END
    END TRY
    BEGIN CATCH
        SET @Result_Message='Operation failed (exception).'; SET @Error_Message=ERROR_MESSAGE();
    END CATCH
END
GO