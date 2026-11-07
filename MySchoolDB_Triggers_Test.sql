use MYSchoolDB;
Go

DECLARE @msg VARCHAR(200), @err VARCHAR(200);

-- #2 level mismatch: student 2026101 is in class level 1; give a level-2 grade -> blocked,
--    surfaced through the SP's error handling (no exception thrown to you, message in @err)
EXEC StudentGrade_SP @Academic_Year=2026, @Semester=1, @Student_Id=2026101,
                     @Subject_Id='MATH', @Course_Level=2,
                     @First_Grade=90, @Second_Grade=90, @third_Grade=90, @Final_Grade=90,
                     @Operation_Type=1, @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
SELECT @msg AS Result, @err AS Error;     -- "Level mismatch: ..."

-- #5 audit: legitimately update an existing grade (85 -> 99), then read the trail
EXEC StudentGrade_SP @Academic_Year=2026, @Semester=1, @Student_Id=2026101,
                     @Subject_Id='ARAB', @Course_Level=1, @First_Grade=99,
                     @Operation_Type=1, @Result_Message=@msg OUTPUT, @Error_Message=@err OUTPUT;
SELECT * FROM Data_Audit WHERE Table_Name='Student_Grades' ORDER BY Audit_Id DESC;


