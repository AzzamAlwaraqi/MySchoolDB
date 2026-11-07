use MYSchoolDB;

Go

DECLARE @msg VARCHAR(200), @err VARCHAR(200);


EXEC Subject_SP @Subject_Id='PHY', @Subject_Name_Ar=N'الفيزياء', @Subject_Name_En='Physics',
                @Required_Level=7, @Operation_Type=1, @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
SELECT @msg AS Result, @err AS Error;

-- unique op: subjects allowed at level 4 (returns a result set)
EXEC Subject_SP @Filter_Level=4, @Operation_Type=4, @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;

----------------------------------------------------------------------------------------------------------
-- teacher's schedule
EXEC Teacher_SP @Teacher_Id=3004, @Operation_Type=4, @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
----------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------
SELECT TOP 10 * FROM Operation_Log ORDER BY Log_Id DESC; 
--------------------------------------------------------------------------------------------------------------

EXEC Class_SP @Class_Level=1, @class_Letter='A', @Operation_Type=5, @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
SELECT @msg AS Result, @err AS Error;

------------------------------------------------------------------------------------------------------------------------

-- who teaches MATH level 4 (op 4)
EXEC Course_SP @Subject_Id='MATH', @Course_Level=4, @Operation_Type=4, @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;

------------------------------------------------------------------------------------------------------------------------

-- find/ensure an address — de-dupes and returns Address_Id (op 1)
EXEC Address_SP @Gov_Id=1, @District=N'خلدا', @Street=N'المدينة', @Building_No='10',
                @Operation_Type=1, @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
SELECT @msg AS Result, @err AS Error;

----------------------------------------------------------------------------------------------------------------------------
-- classification report: students per governorate, ranked (op 5)
EXEC Governorate_SP @Operation_Type=5, @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;

--------------------------------------------------------------------------------------------------------------------------
SELECT TOP 15 * FROM Operation_Log ORDER BY Log_Id DESC;
--------------------------------------------------------------------------------------------------------------------------

EXEC Student_SP @Student_Id=2026101, @Operation_Type=4, @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
SELECT @msg AS Result, @err AS Error;


-- try to delete a student who has grades -> should be blocked
EXEC Student_SP @Student_Id=2026101, @Operation_Type=2, @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
SELECT @msg AS Result, @err AS Error;   -- "Cannot delete: this student has grade records."

-------------------------------------------------------------------------------------------------------------------

-- set a student's main address
EXEC StudentAddress_SP @Student_Id=2026101, @Address_Id=1, @Operation_Type=4, @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;

---------------------------------------------------------------------------------------------------------------------------------------

-- class timetable for 1A
EXEC Assignment_SP @Academic_Year=2026, @Semester=1, @Class_Level=1, @class_Letter='A',
                   @Operation_Type=4, @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
------------------------------------------------------------------------------------------------------------------------------

SELECT TOP 20 * FROM Operation_Log ORDER BY Log_Id DESC;

