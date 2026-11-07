USE MYSchoolDB;
GO
SET QUOTED_IDENTIFIER ON;   -- the XML .nodes()/.value() calls below need this ON
SET ANSI_NULLS ON;
GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='usp_Import')
    DROP PROCEDURE usp_Import;
GO
CREATE PROCEDURE usp_Import
    @Format         VARCHAR(4),
    @Payload        NVARCHAR(MAX),
    @Result_Message VARCHAR(400) OUTPUT,
    @Error_Message  VARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Error_Message = NULL;
    SET @Format = UPPER(LTRIM(RTRIM(@Format)));

    IF @Format NOT IN ('JSON','XML')
    BEGIN
        SET @Result_Message = 'Import failed.';
        SET @Error_Message  = '@Format must be ''JSON'' or ''XML''.';
        EXEC usp_WriteLog N'IMPORT', N'Validate', NULL, 'FAILED', @Result_Message, @Error_Message;
        RETURN;
    END

    IF @Payload IS NULL OR LEN(@Payload) = 0
    BEGIN
        SET @Result_Message = 'Import failed.';
        SET @Error_Message  = '@Payload is empty.';
        EXEC usp_WriteLog N'IMPORT', @Format, NULL, 'FAILED', @Result_Message, @Error_Message;
        RETURN;
    END

    IF @Format = 'JSON' AND ISJSON(@Payload) <> 1
    BEGIN
        SET @Result_Message = 'Import failed.';
        SET @Error_Message  = '@Payload is not valid JSON.';
        EXEC usp_WriteLog N'IMPORT', @Format, NULL, 'FAILED', @Result_Message, @Error_Message;
        RETURN;
    END

    DECLARE @xml XML;
    IF @Format = 'XML'
    BEGIN
        BEGIN TRY
            SET @xml = CAST(@Payload AS XML);
        END TRY
        BEGIN CATCH
            SET @Result_Message = 'Import failed.';
            SET @Error_Message  = '@Payload is not well-formed XML: ' + ERROR_MESSAGE();
            EXEC usp_WriteLog N'IMPORT', @Format, NULL, 'FAILED', @Result_Message, @Error_Message;
            RETURN;
        END CATCH
    END

    -- #Import_Results = per-row report handed back at the end.
    -- #AddrCap swallows the Address_Id that Address_SP SELECTs, so it doesn't leak out.
    CREATE TABLE #Import_Results (
        Seq            INT IDENTITY(1,1) PRIMARY KEY,
        Entity         NVARCHAR(40),
        Row_Num        INT,
        Status         VARCHAR(10),
        Result_Message VARCHAR(200),
        Error_Message  VARCHAR(200)
    );

    CREATE TABLE #AddrCap (Address_Id INT);

    CREATE TABLE #stg_Gov     (RowNum INT IDENTITY(1,1), Gov_Id TINYINT, Gov_Name_Ar NVARCHAR(50), Gov_Name_En VARCHAR(50));
    CREATE TABLE #stg_Subject (RowNum INT IDENTITY(1,1), Subject_Id NVARCHAR(10), Subject_Name_Ar NVARCHAR(50), Subject_Name_En VARCHAR(50), Required_Level TINYINT);
    CREATE TABLE #stg_Teacher (RowNum INT IDENTITY(1,1), Teacher_Id INT, First_name NVARCHAR(30), Last_name NVARCHAR(30), Email VARCHAR(50), Phone_Number VARCHAR(20), hire_date DATE, specialization NVARCHAR(100), is_full_time BIT, qualification NVARCHAR(50));
    CREATE TABLE #stg_Class   (RowNum INT IDENTITY(1,1), Class_Level TINYINT, class_Letter CHAR(1), Student_Capacity TINYINT, Room_Number VARCHAR(20));
    CREATE TABLE #stg_Parent  (RowNum INT IDENTITY(1,1), Parental_Id INT, First_name NVARCHAR(30), Last_name NVARCHAR(30), Email VARCHAR(100), Phone_Number VARCHAR(20), relationship NVARCHAR(30), Occupation NVARCHAR(50));
    CREATE TABLE #stg_Address (RowNum INT IDENTITY(1,1), Address_Id INT, Gov_Id TINYINT, District NVARCHAR(50), Street NVARCHAR(50), Building_No NVARCHAR(10));
    CREATE TABLE #stg_Course  (RowNum INT IDENTITY(1,1), Subject_Id NVARCHAR(10), Course_Level TINYINT, Learning_Materials NVARCHAR(MAX), [Description] NVARCHAR(MAX));
    CREATE TABLE #stg_Student (RowNum INT IDENTITY(1,1), Student_Id INT, First_Name NVARCHAR(30), Last_Name NVARCHAR(30), Date_of_Birth DATE, Gender CHAR(1), Blood_Type VARCHAR(5), Medical_Conditions NVARCHAR(MAX), Class_Level TINYINT, class_Letter CHAR(1), Parental_Id INT);
    CREATE TABLE #stg_StuAddr (RowNum INT IDENTITY(1,1), Student_Id INT, Address_Id INT, Main_Address BIT);
    CREATE TABLE #stg_Assign  (RowNum INT IDENTITY(1,1), Academic_Year SMALLINT, Semester TINYINT, Teacher_Id INT, Class_Level TINYINT, class_Letter CHAR(1), Subject_Id NVARCHAR(10), Course_Level TINYINT);
    CREATE TABLE #stg_Grade   (RowNum INT IDENTITY(1,1), Academic_Year SMALLINT, Semester TINYINT, Student_Id INT, Subject_Id NVARCHAR(10), Course_Level TINYINT, First_Grade INT, Second_Grade INT, third_Grade INT, Final_Grade INT);

    IF @Format = 'JSON'
    BEGIN
        INSERT INTO #stg_Gov (Gov_Id, Gov_Name_Ar, Gov_Name_En)
        SELECT Gov_Id, Gov_Name_Ar, Gov_Name_En
        FROM OPENJSON(@Payload, '$.Governorates')
        WITH (Gov_Id TINYINT '$.Gov_Id', Gov_Name_Ar NVARCHAR(50) '$.Gov_Name_Ar', Gov_Name_En VARCHAR(50) '$.Gov_Name_En');

        INSERT INTO #stg_Subject (Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level)
        SELECT Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level
        FROM OPENJSON(@Payload, '$.Subjects')
        WITH (Subject_Id NVARCHAR(10) '$.Subject_Id', Subject_Name_Ar NVARCHAR(50) '$.Subject_Name_Ar',
              Subject_Name_En VARCHAR(50) '$.Subject_Name_En', Required_Level TINYINT '$.Required_Level');

        INSERT INTO #stg_Teacher (Teacher_Id, First_name, Last_name, Email, Phone_Number, hire_date, specialization, is_full_time, qualification)
        SELECT Teacher_Id, First_name, Last_name, Email, Phone_Number, hire_date, specialization, is_full_time, qualification
        FROM OPENJSON(@Payload, '$.Teacher')
        WITH (Teacher_Id INT '$.Teacher_Id', First_name NVARCHAR(30) '$.First_name', Last_name NVARCHAR(30) '$.Last_name',
              Email VARCHAR(50) '$.Email', Phone_Number VARCHAR(20) '$.Phone_Number', hire_date DATE '$.hire_date',
              specialization NVARCHAR(100) '$.specialization', is_full_time BIT '$.is_full_time', qualification NVARCHAR(50) '$.qualification');

        INSERT INTO #stg_Class (Class_Level, class_Letter, Student_Capacity, Room_Number)
        SELECT Class_Level, class_Letter, Student_Capacity, Room_Number
        FROM OPENJSON(@Payload, '$.Classes')
        WITH (Class_Level TINYINT '$.Class_Level', class_Letter CHAR(1) '$.class_Letter',
              Student_Capacity TINYINT '$.Student_Capacity', Room_Number VARCHAR(20) '$.Room_Number');

        INSERT INTO #stg_Parent (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation)
        SELECT Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation
        FROM OPENJSON(@Payload, '$.Parents')
        WITH (Parental_Id INT '$.Parental_Id', First_name NVARCHAR(30) '$.First_name', Last_name NVARCHAR(30) '$.Last_name',
              Email VARCHAR(100) '$.Email', Phone_Number VARCHAR(20) '$.Phone_Number', relationship NVARCHAR(30) '$.relationship', Occupation NVARCHAR(50) '$.Occupation');

        INSERT INTO #stg_Address (Address_Id, Gov_Id, District, Street, Building_No)
        SELECT Address_Id, Gov_Id, District, Street, Building_No
        FROM OPENJSON(@Payload, '$.Addresses')
        WITH (Address_Id INT '$.Address_Id', Gov_Id TINYINT '$.Gov_Id', District NVARCHAR(50) '$.District',
              Street NVARCHAR(50) '$.Street', Building_No NVARCHAR(10) '$.Building_No');

        INSERT INTO #stg_Course (Subject_Id, Course_Level, Learning_Materials, [Description])
        SELECT Subject_Id, Course_Level, Learning_Materials, [Description]
        FROM OPENJSON(@Payload, '$.Courses')
        WITH (Subject_Id NVARCHAR(10) '$.Subject_Id', Course_Level TINYINT '$.Course_Level',
              Learning_Materials NVARCHAR(MAX) '$.Learning_Materials', [Description] NVARCHAR(MAX) '$.Description');

        INSERT INTO #stg_Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id)
        SELECT Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id
        FROM OPENJSON(@Payload, '$.Students')
        WITH (Student_Id INT '$.Student_Id', First_Name NVARCHAR(30) '$.First_Name', Last_Name NVARCHAR(30) '$.Last_Name',
              Date_of_Birth DATE '$.Date_of_Birth', Gender CHAR(1) '$.Gender', Blood_Type VARCHAR(5) '$.Blood_Type',
              Medical_Conditions NVARCHAR(MAX) '$.Medical_Conditions', Class_Level TINYINT '$.Class_Level',
              class_Letter CHAR(1) '$.class_Letter', Parental_Id INT '$.Parental_Id');

        INSERT INTO #stg_StuAddr (Student_Id, Address_Id, Main_Address)
        SELECT Student_Id, Address_Id, Main_Address
        FROM OPENJSON(@Payload, '$.Student_Addresses')
        WITH (Student_Id INT '$.Student_Id', Address_Id INT '$.Address_Id', Main_Address BIT '$.Main_Address');

        INSERT INTO #stg_Assign (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level)
        SELECT Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level
        FROM OPENJSON(@Payload, '$.Assignments')
        WITH (Academic_Year SMALLINT '$.Academic_Year', Semester TINYINT '$.Semester', Teacher_Id INT '$.Teacher_Id',
              Class_Level TINYINT '$.Class_Level', class_Letter CHAR(1) '$.class_Letter',
              Subject_Id NVARCHAR(10) '$.Subject_Id', Course_Level TINYINT '$.Course_Level');

        INSERT INTO #stg_Grade (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade)
        SELECT Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade
        FROM OPENJSON(@Payload, '$.Grades')
        WITH (Academic_Year SMALLINT '$.Academic_Year', Semester TINYINT '$.Semester', Student_Id INT '$.Student_Id',
              Subject_Id NVARCHAR(10) '$.Subject_Id', Course_Level TINYINT '$.Course_Level', First_Grade INT '$.First_Grade',
              Second_Grade INT '$.Second_Grade', third_Grade INT '$.third_Grade', Final_Grade INT '$.Final_Grade');
    END
    ELSE
    BEGIN
        INSERT INTO #stg_Gov (Gov_Id, Gov_Name_Ar, Gov_Name_En)
        SELECT n.value('@Gov_Id','TINYINT'), n.value('@Gov_Name_Ar','NVARCHAR(50)'), n.value('@Gov_Name_En','VARCHAR(50)')
        FROM @xml.nodes('/MySchoolImport/Governorates/Governorate') AS t(n);

        INSERT INTO #stg_Subject (Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level)
        SELECT n.value('@Subject_Id','NVARCHAR(10)'), n.value('@Subject_Name_Ar','NVARCHAR(50)'),
               n.value('@Subject_Name_En','VARCHAR(50)'), n.value('@Required_Level','TINYINT')
        FROM @xml.nodes('/MySchoolImport/Subjects/Subject') AS t(n);

        INSERT INTO #stg_Teacher (Teacher_Id, First_name, Last_name, Email, Phone_Number, hire_date, specialization, is_full_time, qualification)
        SELECT n.value('@Teacher_Id','INT'), n.value('@First_name','NVARCHAR(30)'), n.value('@Last_name','NVARCHAR(30)'),
               n.value('@Email','VARCHAR(50)'), n.value('@Phone_Number','VARCHAR(20)'), n.value('@hire_date','DATE'),
               n.value('@specialization','NVARCHAR(100)'), n.value('@is_full_time','BIT'), n.value('@qualification','NVARCHAR(50)')
        FROM @xml.nodes('/MySchoolImport/Teachers/Teacher') AS t(n);

        INSERT INTO #stg_Class (Class_Level, class_Letter, Student_Capacity, Room_Number)
        SELECT n.value('@Class_Level','TINYINT'), n.value('@class_Letter','CHAR(1)'),
               n.value('@Student_Capacity','TINYINT'), n.value('@Room_Number','VARCHAR(20)')
        FROM @xml.nodes('/MySchoolImport/Classes/Class') AS t(n);

        INSERT INTO #stg_Parent (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation)
        SELECT n.value('@Parental_Id','INT'), n.value('@First_name','NVARCHAR(30)'), n.value('@Last_name','NVARCHAR(30)'),
               n.value('@Email','VARCHAR(100)'), n.value('@Phone_Number','VARCHAR(20)'), n.value('@relationship','NVARCHAR(30)'), n.value('@Occupation','NVARCHAR(50)')
        FROM @xml.nodes('/MySchoolImport/Parents/Parent') AS t(n);

        INSERT INTO #stg_Address (Address_Id, Gov_Id, District, Street, Building_No)
        SELECT n.value('@Address_Id','INT'), n.value('@Gov_Id','TINYINT'), n.value('@District','NVARCHAR(50)'),
               n.value('@Street','NVARCHAR(50)'), n.value('@Building_No','NVARCHAR(10)')
        FROM @xml.nodes('/MySchoolImport/Addresses/Address') AS t(n);

        INSERT INTO #stg_Course (Subject_Id, Course_Level, Learning_Materials, [Description])
        SELECT n.value('@Subject_Id','NVARCHAR(10)'), n.value('@Course_Level','TINYINT'),
               n.value('@Learning_Materials','NVARCHAR(MAX)'), n.value('@Description','NVARCHAR(MAX)')
        FROM @xml.nodes('/MySchoolImport/Courses/Course') AS t(n);

        INSERT INTO #stg_Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id)
        SELECT n.value('@Student_Id','INT'), n.value('@First_Name','NVARCHAR(30)'), n.value('@Last_Name','NVARCHAR(30)'),
               n.value('@Date_of_Birth','DATE'), n.value('@Gender','CHAR(1)'), n.value('@Blood_Type','VARCHAR(5)'),
               n.value('@Medical_Conditions','NVARCHAR(MAX)'), n.value('@Class_Level','TINYINT'),
               n.value('@class_Letter','CHAR(1)'), n.value('@Parental_Id','INT')
        FROM @xml.nodes('/MySchoolImport/Students/Student') AS t(n);

        INSERT INTO #stg_StuAddr (Student_Id, Address_Id, Main_Address)
        SELECT n.value('@Student_Id','INT'), n.value('@Address_Id','INT'), n.value('@Main_Address','BIT')
        FROM @xml.nodes('/MySchoolImport/Student_Addresses/Student_Address') AS t(n);

        INSERT INTO #stg_Assign (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level)
        SELECT n.value('@Academic_Year','SMALLINT'), n.value('@Semester','TINYINT'), n.value('@Teacher_Id','INT'),
               n.value('@Class_Level','TINYINT'), n.value('@class_Letter','CHAR(1)'),
               n.value('@Subject_Id','NVARCHAR(10)'), n.value('@Course_Level','TINYINT')
        FROM @xml.nodes('/MySchoolImport/Assignments/Assignment') AS t(n);

        INSERT INTO #stg_Grade (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade)
        SELECT n.value('@Academic_Year','SMALLINT'), n.value('@Semester','TINYINT'), n.value('@Student_Id','INT'),
               n.value('@Subject_Id','NVARCHAR(10)'), n.value('@Course_Level','TINYINT'), n.value('@First_Grade','INT'),
               n.value('@Second_Grade','INT'), n.value('@third_Grade','INT'), n.value('@Final_Grade','INT')
        FROM @xml.nodes('/MySchoolImport/Grades/Grade') AS t(n);
    END

    -- Same pattern per entity (parent-first): loop the staged rows, call the _SP in
    -- a TRY/CATCH so one bad row can't abort the batch, tally ok/fail, log each row.
    DECLARE @i INT, @n INT;
    DECLARE @msg VARCHAR(200), @err VARCHAR(200);
    DECLARE @ok INT = 0, @fail INT = 0;

    DECLARE @Gov_Id TINYINT, @Gov_Name_Ar NVARCHAR(50), @Gov_Name_En VARCHAR(50);
    DECLARE @Subject_Id NVARCHAR(10), @Subject_Name_Ar NVARCHAR(50), @Subject_Name_En VARCHAR(50), @Required_Level TINYINT;
    DECLARE @Teacher_Id INT, @T_First NVARCHAR(30), @T_Last NVARCHAR(30), @T_Email VARCHAR(50), @T_Phone VARCHAR(20),
            @hire_date DATE, @specialization NVARCHAR(100), @is_full_time BIT, @qualification NVARCHAR(50);
    DECLARE @Class_Level TINYINT, @class_Letter CHAR(1), @Student_Capacity TINYINT, @Room_Number VARCHAR(20);
    DECLARE @Parental_Id INT, @P_First NVARCHAR(30), @P_Last NVARCHAR(30), @P_Email VARCHAR(100), @P_Phone VARCHAR(20),
            @relationship NVARCHAR(30), @Occupation NVARCHAR(50);
    DECLARE @Address_Id INT, @District NVARCHAR(50), @Street NVARCHAR(50), @Building_No NVARCHAR(10);
    DECLARE @Course_Level TINYINT, @Learning_Materials NVARCHAR(MAX), @Description NVARCHAR(MAX);
    DECLARE @Student_Id INT, @S_First NVARCHAR(30), @S_Last NVARCHAR(30), @Date_of_Birth DATE, @Gender CHAR(1),
            @Blood_Type VARCHAR(5), @Medical NVARCHAR(MAX);
    DECLARE @Main_Address BIT;
    DECLARE @Academic_Year SMALLINT, @Semester TINYINT;
    DECLARE @First_Grade INT, @Second_Grade INT, @third_Grade INT, @Final_Grade INT;
    DECLARE @govKey NVARCHAR(100);

    SET @n = ISNULL((SELECT MAX(RowNum) FROM #stg_Gov), 0);  SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SELECT @Gov_Id = Gov_Id, @Gov_Name_Ar = Gov_Name_Ar, @Gov_Name_En = Gov_Name_En
        FROM #stg_Gov WHERE RowNum = @i;
        SET @msg = NULL;  SET @err = NULL;

        BEGIN TRY
            IF @Gov_Id IS NULL OR @Gov_Name_Ar IS NULL OR @Gov_Name_En IS NULL
                SET @err = 'Gov_Id, Gov_Name_Ar and Gov_Name_En are required.';
            ELSE IF EXISTS (SELECT 1 FROM Governorates WHERE Gov_Id = @Gov_Id)
                SET @msg = 'Governorate already exists (skipped).';
            ELSE
            BEGIN
                INSERT INTO Governorates (Gov_Id, Gov_Name_Ar, Gov_Name_En)
                VALUES (@Gov_Id, @Gov_Name_Ar, @Gov_Name_En);
                SET @msg = 'Governorate inserted.';
            END
        END TRY
        BEGIN CATCH SET @err = ERROR_MESSAGE(); END CATCH

        SET @govKey = CAST(@Gov_Id AS NVARCHAR(100));
        IF @err IS NULL EXEC usp_WriteLog N'Governorates', N'Import', @govKey, 'SUCCESS', @msg, NULL;
        ELSE            EXEC usp_WriteLog N'Governorates', N'Import', @govKey, 'FAILED', 'Import row rejected.', @err;

        INSERT INTO #Import_Results (Entity, Row_Num, Status, Result_Message, Error_Message)
        VALUES (N'Governorates', @i, CASE WHEN @err IS NULL THEN 'OK' ELSE 'FAILED' END, @msg, @err);
        IF @err IS NULL SET @ok += 1; ELSE SET @fail += 1;
        SET @i += 1;
    END

    SET @n = ISNULL((SELECT MAX(RowNum) FROM #stg_Subject), 0);  SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SELECT @Subject_Id = Subject_Id, @Subject_Name_Ar = Subject_Name_Ar,
               @Subject_Name_En = Subject_Name_En, @Required_Level = Required_Level
        FROM #stg_Subject WHERE RowNum = @i;
        SET @msg = NULL;  SET @err = NULL;

        BEGIN TRY
            EXEC Subject_SP @Subject_Id=@Subject_Id, @Subject_Name_Ar=@Subject_Name_Ar, @Subject_Name_En=@Subject_Name_En,
                            @Required_Level=@Required_Level, @Operation_Type=1,
                            @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
        END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); SET @msg = 'Exception during Save.'; END CATCH

        INSERT INTO #Import_Results (Entity, Row_Num, Status, Result_Message, Error_Message)
        VALUES (N'Subjects', @i, CASE WHEN @err IS NULL THEN 'OK' ELSE 'FAILED' END, @msg, @err);
        IF @err IS NULL SET @ok += 1; ELSE SET @fail += 1;
        SET @i += 1;
    END

    SET @n = ISNULL((SELECT MAX(RowNum) FROM #stg_Teacher), 0);  SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SELECT @Teacher_Id = Teacher_Id, @T_First = First_name, @T_Last = Last_name, @T_Email = Email, @T_Phone = Phone_Number,
               @hire_date = hire_date, @specialization = specialization, @is_full_time = is_full_time, @qualification = qualification
        FROM #stg_Teacher WHERE RowNum = @i;
        SET @msg = NULL;  SET @err = NULL;

        BEGIN TRY
            EXEC Teacher_SP @Teacher_Id=@Teacher_Id, @First_name=@T_First, @Last_name=@T_Last, @Email=@T_Email,
                            @Phone_Number=@T_Phone, @hire_date=@hire_date, @specialization=@specialization,
                            @is_full_time=@is_full_time, @qualification=@qualification, @Operation_Type=1,
                            @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
        END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); SET @msg = 'Exception during Save.'; END CATCH

        INSERT INTO #Import_Results (Entity, Row_Num, Status, Result_Message, Error_Message)
        VALUES (N'Teacher', @i, CASE WHEN @err IS NULL THEN 'OK' ELSE 'FAILED' END, @msg, @err);
        IF @err IS NULL SET @ok += 1; ELSE SET @fail += 1;
        SET @i += 1;
    END

    SET @n = ISNULL((SELECT MAX(RowNum) FROM #stg_Class), 0);  SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SELECT @Class_Level = Class_Level, @class_Letter = class_Letter,
               @Student_Capacity = Student_Capacity, @Room_Number = Room_Number
        FROM #stg_Class WHERE RowNum = @i;
        SET @msg = NULL;  SET @err = NULL;

        BEGIN TRY
            EXEC Class_SP @class_Letter=@class_Letter, @Student_Capacity=@Student_Capacity, @Class_Level=@Class_Level,
                          @Room_Number=@Room_Number, @Operation_Type=1,
                          @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
        END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); SET @msg = 'Exception during Save.'; END CATCH

        INSERT INTO #Import_Results (Entity, Row_Num, Status, Result_Message, Error_Message)
        VALUES (N'class', @i, CASE WHEN @err IS NULL THEN 'OK' ELSE 'FAILED' END, @msg, @err);
        IF @err IS NULL SET @ok += 1; ELSE SET @fail += 1;
        SET @i += 1;
    END

    SET @n = ISNULL((SELECT MAX(RowNum) FROM #stg_Parent), 0);  SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SELECT @Parental_Id = Parental_Id, @P_First = First_name, @P_Last = Last_name, @P_Email = Email,
               @P_Phone = Phone_Number, @relationship = relationship, @Occupation = Occupation
        FROM #stg_Parent WHERE RowNum = @i;
        SET @msg = NULL;  SET @err = NULL;

        BEGIN TRY
            EXEC Parent_SP @Parental_Id=@Parental_Id, @First_name=@P_First, @Last_name=@P_Last, @Email=@P_Email,
                           @Phone_Number=@P_Phone, @relationship=@relationship, @Occupation=@Occupation, @Operation_Type=1,
                           @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
        END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); SET @msg = 'Exception during Save.'; END CATCH

        INSERT INTO #Import_Results (Entity, Row_Num, Status, Result_Message, Error_Message)
        VALUES (N'Parents', @i, CASE WHEN @err IS NULL THEN 'OK' ELSE 'FAILED' END, @msg, @err);
        IF @err IS NULL SET @ok += 1; ELSE SET @fail += 1;
        SET @i += 1;
    END

    SET @n = ISNULL((SELECT MAX(RowNum) FROM #stg_Address), 0);  SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SELECT @Address_Id = Address_Id, @Gov_Id = Gov_Id, @District = District, @Street = Street, @Building_No = Building_No
        FROM #stg_Address WHERE RowNum = @i;
        SET @msg = NULL;  SET @err = NULL;

        BEGIN TRY
            INSERT INTO #AddrCap (Address_Id)
            EXEC Address_SP @Address_Id=@Address_Id, @Gov_Id=@Gov_Id, @District=@District, @Street=@Street,
                            @Building_No=@Building_No, @Operation_Type=1,
                            @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
        END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); SET @msg = 'Exception during Save.'; END CATCH

        INSERT INTO #Import_Results (Entity, Row_Num, Status, Result_Message, Error_Message)
        VALUES (N'Address', @i, CASE WHEN @err IS NULL THEN 'OK' ELSE 'FAILED' END, @msg, @err);
        IF @err IS NULL SET @ok += 1; ELSE SET @fail += 1;
        SET @i += 1;
    END

    SET @n = ISNULL((SELECT MAX(RowNum) FROM #stg_Course), 0);  SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SELECT @Subject_Id = Subject_Id, @Course_Level = Course_Level,
               @Learning_Materials = Learning_Materials, @Description = [Description]
        FROM #stg_Course WHERE RowNum = @i;
        SET @msg = NULL;  SET @err = NULL;

        BEGIN TRY
            EXEC Course_SP @Subject_Id=@Subject_Id, @Learning_Materials=@Learning_Materials, @Description=@Description,
                           @Course_Level=@Course_Level, @Operation_Type=1,
                           @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
        END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); SET @msg = 'Exception during Save.'; END CATCH

        INSERT INTO #Import_Results (Entity, Row_Num, Status, Result_Message, Error_Message)
        VALUES (N'Courses', @i, CASE WHEN @err IS NULL THEN 'OK' ELSE 'FAILED' END, @msg, @err);
        IF @err IS NULL SET @ok += 1; ELSE SET @fail += 1;
        SET @i += 1;
    END

    SET @n = ISNULL((SELECT MAX(RowNum) FROM #stg_Student), 0);  SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SELECT @Student_Id = Student_Id, @S_First = First_Name, @S_Last = Last_Name, @Date_of_Birth = Date_of_Birth,
               @Gender = Gender, @Blood_Type = Blood_Type, @Medical = Medical_Conditions,
               @Class_Level = Class_Level, @class_Letter = class_Letter, @Parental_Id = Parental_Id
        FROM #stg_Student WHERE RowNum = @i;
        SET @msg = NULL;  SET @err = NULL;

        BEGIN TRY
            EXEC Student_SP @Student_Id=@Student_Id, @First_Name=@S_First, @Last_Name=@S_Last, @Date_of_Birth=@Date_of_Birth,
                            @Gender=@Gender, @Blood_Type=@Blood_Type, @Medical_Conditions=@Medical, @Class_Level=@Class_Level,
                            @class_Letter=@class_Letter, @Parental_Id=@Parental_Id, @Operation_Type=1,
                            @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
        END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); SET @msg = 'Exception during Save.'; END CATCH

        INSERT INTO #Import_Results (Entity, Row_Num, Status, Result_Message, Error_Message)
        VALUES (N'Student', @i, CASE WHEN @err IS NULL THEN 'OK' ELSE 'FAILED' END, @msg, @err);
        IF @err IS NULL SET @ok += 1; ELSE SET @fail += 1;
        SET @i += 1;
    END

    SET @n = ISNULL((SELECT MAX(RowNum) FROM #stg_StuAddr), 0);  SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SELECT @Student_Id = Student_Id, @Address_Id = Address_Id, @Main_Address = Main_Address
        FROM #stg_StuAddr WHERE RowNum = @i;
        SET @msg = NULL;  SET @err = NULL;

        BEGIN TRY
            EXEC StudentAddress_SP @Student_Id=@Student_Id, @Address_Id=@Address_Id, @Main_Address=@Main_Address,
                                   @Operation_Type=1, @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
        END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); SET @msg = 'Exception during Link.'; END CATCH

        INSERT INTO #Import_Results (Entity, Row_Num, Status, Result_Message, Error_Message)
        VALUES (N'Student_Addresses', @i, CASE WHEN @err IS NULL THEN 'OK' ELSE 'FAILED' END, @msg, @err);
        IF @err IS NULL SET @ok += 1; ELSE SET @fail += 1;
        SET @i += 1;
    END

    SET @n = ISNULL((SELECT MAX(RowNum) FROM #stg_Assign), 0);  SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SELECT @Academic_Year = Academic_Year, @Semester = Semester, @Teacher_Id = Teacher_Id, @Class_Level = Class_Level,
               @class_Letter = class_Letter, @Subject_Id = Subject_Id, @Course_Level = Course_Level
        FROM #stg_Assign WHERE RowNum = @i;
        SET @msg = NULL;  SET @err = NULL;

        BEGIN TRY
            EXEC Assignment_SP @Academic_Year=@Academic_Year, @Semester=@Semester, @Teacher_Id=@Teacher_Id, @Class_Level=@Class_Level,
                               @class_Letter=@class_Letter, @Subject_Id=@Subject_Id, @Course_Level=@Course_Level, @Operation_Type=1,
                               @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
        END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); SET @msg = 'Exception during Save.'; END CATCH

        INSERT INTO #Import_Results (Entity, Row_Num, Status, Result_Message, Error_Message)
        VALUES (N'Teacher_Class_Assignments', @i, CASE WHEN @err IS NULL THEN 'OK' ELSE 'FAILED' END, @msg, @err);
        IF @err IS NULL SET @ok += 1; ELSE SET @fail += 1;
        SET @i += 1;
    END

    SET @n = ISNULL((SELECT MAX(RowNum) FROM #stg_Grade), 0);  SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SELECT @Academic_Year = Academic_Year, @Semester = Semester, @Student_Id = Student_Id, @Subject_Id = Subject_Id, @Course_Level = Course_Level,
               @First_Grade = First_Grade, @Second_Grade = Second_Grade, @third_Grade = third_Grade, @Final_Grade = Final_Grade
        FROM #stg_Grade WHERE RowNum = @i;
        SET @msg = NULL;  SET @err = NULL;

        BEGIN TRY
            EXEC StudentGrade_SP @Academic_Year=@Academic_Year, @Semester=@Semester, @Student_Id=@Student_Id, @Subject_Id=@Subject_Id,
                                 @Course_Level=@Course_Level, @First_Grade=@First_Grade, @Second_Grade=@Second_Grade,
                                 @third_Grade=@third_Grade, @Final_Grade=@Final_Grade, @Operation_Type=1,
                                 @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
        END TRY BEGIN CATCH SET @err = ERROR_MESSAGE(); SET @msg = 'Exception during Save.'; END CATCH

        INSERT INTO #Import_Results (Entity, Row_Num, Status, Result_Message, Error_Message)
        VALUES (N'Student_Grades', @i, CASE WHEN @err IS NULL THEN 'OK' ELSE 'FAILED' END, @msg, @err);
        IF @err IS NULL SET @ok += 1; ELSE SET @fail += 1;
        SET @i += 1;
    END

    IF @ok = 0 AND @fail = 0
    BEGIN
        SET @Result_Message = 'Import (' + @Format + '): no importable rows were found.';
        SET @Error_Message  = 'Check the document shape - JSON keys (Subjects, Teacher, Students, ...) '
                            + 'or XML root <MySchoolImport> and element names must match exactly.';
    END
    ELSE
    BEGIN
        SET @Result_Message = 'Import (' + @Format + ') complete: '
                            + CAST(@ok AS VARCHAR(10)) + ' succeeded, '
                            + CAST(@fail AS VARCHAR(10)) + ' failed.';
        IF @fail > 0
            SET @Error_Message = CAST(@fail AS VARCHAR(10))
                               + ' row(s) rejected. See the result set (Status = FAILED) for the reason on each.';
    END

    DECLARE @ImportStatus VARCHAR(10) = CASE WHEN @fail = 0 THEN 'SUCCESS' ELSE 'FAILED' END;
    EXEC usp_WriteLog N'IMPORT', @Format, NULL, @ImportStatus, @Result_Message, @Error_Message;

    SELECT Entity, Row_Num, Status, Result_Message, Error_Message
    FROM #Import_Results
    ORDER BY Seq;
END
GO

-- Thin wrappers so callers skip the @Format flag.
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='usp_Import_JSON')
    DROP PROCEDURE usp_Import_JSON;
GO
CREATE PROCEDURE usp_Import_JSON
    @Payload        NVARCHAR(MAX),
    @Result_Message VARCHAR(400) OUTPUT,
    @Error_Message  VARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC usp_Import @Format='JSON', @Payload=@Payload,
                    @Result_Message=@Result_Message OUTPUT, @Error_Message=@Error_Message OUTPUT;
END
GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='usp_Import_XML')
    DROP PROCEDURE usp_Import_XML;
GO
CREATE PROCEDURE usp_Import_XML
    @Payload        NVARCHAR(MAX),
    @Result_Message VARCHAR(400) OUTPUT,
    @Error_Message  VARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC usp_Import @Format='XML', @Payload=@Payload,
                    @Result_Message=@Result_Message OUTPUT, @Error_Message=@Error_Message OUTPUT;
END
GO
