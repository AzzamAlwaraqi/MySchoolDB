USE MYSchoolDB;
GO

-------------------------------------------------------------------
-- GENERATING CLASSES 
-------------------------------------------------------------------
DECLARE @ClassLvl TINYINT = 1;
WHILE @ClassLvl <= 7
BEGIN
    IF NOT EXISTS (SELECT 1 FROM class WHERE Class_Level = @ClassLvl AND class_Letter = 'A')
        INSERT INTO class (Class_Level, class_Letter, Student_Capacity, Room_Number) 
        VALUES (@ClassLvl, 'A', 30, CAST(@ClassLvl AS VARCHAR(10)) + '01'); 
    SET @ClassLvl = @ClassLvl + 1;
END
GO

-------------------------------------------------------------------
-- ADDING SUBJECTS   (FIX: Min_Level -> Required_Level)
-------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Subjects WHERE Subject_Id = 'ARAB') INSERT INTO Subjects (Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level) VALUES ('ARAB', N'اللغة العربية', 'Arabic', 1);
IF NOT EXISTS (SELECT 1 FROM Subjects WHERE Subject_Id = 'ENG')  INSERT INTO Subjects (Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level) VALUES ('ENG', N'اللغة الإنجليزية', 'English', 1);
IF NOT EXISTS (SELECT 1 FROM Subjects WHERE Subject_Id = 'MATH') INSERT INTO Subjects (Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level) VALUES ('MATH', N'الرياضيات', 'Math', 1);
IF NOT EXISTS (SELECT 1 FROM Subjects WHERE Subject_Id = 'SCI')  INSERT INTO Subjects (Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level) VALUES ('SCI', N'العلوم', 'Science', 1);
IF NOT EXISTS (SELECT 1 FROM Subjects WHERE Subject_Id = 'ART')  INSERT INTO Subjects (Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level) VALUES ('ART', N'التربية الفنية', 'Art', 1);
IF NOT EXISTS (SELECT 1 FROM Subjects WHERE Subject_Id = 'SPO')  INSERT INTO Subjects (Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level) VALUES ('SPO', N'التربية الرياضية', 'Sports', 1);
IF NOT EXISTS (SELECT 1 FROM Subjects WHERE Subject_Id = 'ISLM') INSERT INTO Subjects (Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level) VALUES ('ISLM', N'التربية الإسلامية', 'Islamic Studies', 1);
IF NOT EXISTS (SELECT 1 FROM Subjects WHERE Subject_Id = 'HIST') INSERT INTO Subjects (Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level) VALUES ('HIST', N'التاريخ', 'History', 4);
IF NOT EXISTS (SELECT 1 FROM Subjects WHERE Subject_Id = 'GEO')  INSERT INTO Subjects (Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level) VALUES ('GEO', N'الجغرافيا', 'Geography', 4);
IF NOT EXISTS (SELECT 1 FROM Subjects WHERE Subject_Id = 'COMP') INSERT INTO Subjects (Subject_Id, Subject_Name_Ar, Subject_Name_En, Required_Level) VALUES ('COMP', N'الحاسوب', 'Computer IT', 5);
GO

-------------------------------------------------------------------
-- ADDING TEACHERS 
-------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Teacher WHERE Teacher_Id = 3001) INSERT INTO Teacher (Teacher_Id, First_name, Last_name, Email, Phone_Number, specialization, qualification) VALUES (3001, N'فاطمة', N'علي', 'fatima@school.jo', '0793000001', N'لغة عربية', N'بكالوريوس');
IF NOT EXISTS (SELECT 1 FROM Teacher WHERE Teacher_Id = 3002) INSERT INTO Teacher (Teacher_Id, First_name, Last_name, Email, Phone_Number, specialization, qualification) VALUES (3002, N'أحمد', N'حسن', 'ahmad@school.jo', '0793000002', N'لغة إنجليزية', N'بكالوريوس');
IF NOT EXISTS (SELECT 1 FROM Teacher WHERE Teacher_Id = 3003) INSERT INTO Teacher (Teacher_Id, First_name, Last_name, Email, Phone_Number, specialization, qualification) VALUES (3003, N'سامر', N'فريد', 'samer@school.jo', '0793000003', N'رياضيات صفوف صغرى', N'بكالوريوس');
IF NOT EXISTS (SELECT 1 FROM Teacher WHERE Teacher_Id = 3004) INSERT INTO Teacher (Teacher_Id, First_name, Last_name, Email, Phone_Number, specialization, qualification) VALUES (3004, N'ليلى', N'كرم', 'layla@school.jo', '0793000004', N'رياضيات صفوف عليا', N'ماجستير');
IF NOT EXISTS (SELECT 1 FROM Teacher WHERE Teacher_Id = 3005) INSERT INTO Teacher (Teacher_Id, First_name, Last_name, Email, Phone_Number, specialization, qualification) VALUES (3005, N'هدى', N'سعد', 'huda@school.jo', '0793000005', N'علوم صفوف صغرى', N'بكالوريوس');
IF NOT EXISTS (SELECT 1 FROM Teacher WHERE Teacher_Id = 3006) INSERT INTO Teacher (Teacher_Id, First_name, Last_name, Email, Phone_Number, specialization, qualification) VALUES (3006, N'عمر', N'زيد', 'omar@school.jo', '0793000006', N'علوم صفوف عليا', N'ماجستير');
IF NOT EXISTS (SELECT 1 FROM Teacher WHERE Teacher_Id = 3007) INSERT INTO Teacher (Teacher_Id, First_name, Last_name, Email, Phone_Number, specialization, qualification) VALUES (3007, N'طارق', N'نواف', 'tariq@school.jo', '0793000007', N'تاريخ وجغرافيا', N'بكالوريوس');
IF NOT EXISTS (SELECT 1 FROM Teacher WHERE Teacher_Id = 3008) INSERT INTO Teacher (Teacher_Id, First_name, Last_name, Email, Phone_Number, specialization, qualification) VALUES (3008, N'زيد', N'بدر', 'zaid@school.jo', '0793000008', N'رياضة', N'بكالوريوس');
IF NOT EXISTS (SELECT 1 FROM Teacher WHERE Teacher_Id = 3009) INSERT INTO Teacher (Teacher_Id, First_name, Last_name, Email, Phone_Number, specialization, qualification) VALUES (3009, N'سناء', N'مروان', 'sanaa.m@school.jo', '0793000009', N'فن', N'بكالوريوس');
IF NOT EXISTS (SELECT 1 FROM Teacher WHERE Teacher_Id = 3010) INSERT INTO Teacher (Teacher_Id, First_name, Last_name, Email, Phone_Number, specialization, qualification) VALUES (3010, N'محمود', N'صلاح', 'mahmoud@school.jo', '0793000010', N'حاسوب', N'بكالوريوس');
-- Dedicated Islamic Studies Teacher
IF NOT EXISTS (SELECT 1 FROM Teacher WHERE Teacher_Id = 3011) INSERT INTO Teacher (Teacher_Id, First_name, Last_name, Email, Phone_Number, specialization, qualification) VALUES (3011, N'إبراهيم', N'الخطيب', 'ibrahim@school.jo', '0793000011', N'تربية إسلامية', N'بكالوريوس');
GO

-------------------------------------------------------------------
-- GENERATING COURSES & ASSIGNMENTS (Grades 1-7)
-------------------------------------------------------------------
DECLARE @lvl INT = 1;

WHILE @lvl <= 7
BEGIN
    -----------------------------------------------------------------
    -- A. CREATE THE COURSES FOR THIS LEVEL 
    -----------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Courses WHERE Subject_Id='ARAB' AND Course_Level=@lvl) INSERT INTO Courses (Subject_Id, Learning_Materials, [Description], Course_Level) VALUES ('ARAB', 'Arabic Book ' + CAST(@lvl AS VARCHAR(10)), N'لغة عربية للصف ' + CAST(@lvl AS VARCHAR(10)), @lvl);
    IF NOT EXISTS (SELECT 1 FROM Courses WHERE Subject_Id='ENG' AND Course_Level=@lvl)  INSERT INTO Courses (Subject_Id, Learning_Materials, [Description], Course_Level) VALUES ('ENG', 'English Book ' + CAST(@lvl AS VARCHAR(10)), N'لغة إنجليزية للصف ' + CAST(@lvl AS VARCHAR(10)), @lvl);
    IF NOT EXISTS (SELECT 1 FROM Courses WHERE Subject_Id='MATH' AND Course_Level=@lvl) INSERT INTO Courses (Subject_Id, Learning_Materials, [Description], Course_Level) VALUES ('MATH', 'Math Book ' + CAST(@lvl AS VARCHAR(10)), N'رياضيات للصف ' + CAST(@lvl AS VARCHAR(10)), @lvl);
    IF NOT EXISTS (SELECT 1 FROM Courses WHERE Subject_Id='SCI' AND Course_Level=@lvl)  INSERT INTO Courses (Subject_Id, Learning_Materials, [Description], Course_Level) VALUES ('SCI', 'Science Book ' + CAST(@lvl AS VARCHAR(10)), N'علوم للصف ' + CAST(@lvl AS VARCHAR(10)), @lvl);
    IF NOT EXISTS (SELECT 1 FROM Courses WHERE Subject_Id='ART' AND Course_Level=@lvl)  INSERT INTO Courses (Subject_Id, Learning_Materials, [Description], Course_Level) VALUES ('ART', 'Art Supplies', N'فن للصف ' + CAST(@lvl AS VARCHAR(10)), @lvl);
    IF NOT EXISTS (SELECT 1 FROM Courses WHERE Subject_Id='SPO' AND Course_Level=@lvl)  INSERT INTO Courses (Subject_Id, Learning_Materials, [Description], Course_Level) VALUES ('SPO', 'Sports Equipment', N'رياضة للصف ' + CAST(@lvl AS VARCHAR(10)), @lvl);
    IF NOT EXISTS (SELECT 1 FROM Courses WHERE Subject_Id='ISLM' AND Course_Level=@lvl) INSERT INTO Courses (Subject_Id, Learning_Materials, [Description], Course_Level) VALUES ('ISLM', 'Islamic Book ' + CAST(@lvl AS VARCHAR(10)), N'دين للصف ' + CAST(@lvl AS VARCHAR(10)), @lvl);

    IF @lvl >= 4 BEGIN
        IF NOT EXISTS (SELECT 1 FROM Courses WHERE Subject_Id='HIST' AND Course_Level=@lvl) INSERT INTO Courses (Subject_Id, Learning_Materials, [Description], Course_Level) VALUES ('HIST', 'History Book', N'تاريخ', @lvl);
        IF NOT EXISTS (SELECT 1 FROM Courses WHERE Subject_Id='GEO' AND Course_Level=@lvl)  INSERT INTO Courses (Subject_Id, Learning_Materials, [Description], Course_Level) VALUES ('GEO', 'Geography Book', N'جغرافيا', @lvl);
    END
    IF @lvl >= 5 BEGIN
        IF NOT EXISTS (SELECT 1 FROM Courses WHERE Subject_Id='COMP' AND Course_Level=@lvl) INSERT INTO Courses (Subject_Id, Learning_Materials, [Description], Course_Level) VALUES ('COMP', 'IT Lab Manual', N'حاسوب', @lvl);
    END

    ----------------------------------------------------------
    -- B. ASSIGN TEACHERS TO CLASSES 
    ----------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Academic_Year=2026 AND Semester=1 AND Teacher_Id=3001 AND Class_Level=@lvl AND class_Letter='A' AND Subject_Id='ARAB') 
        INSERT INTO Teacher_Class_Assignments (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level) VALUES (2026, 1, 3001, @lvl, 'A', 'ARAB', @lvl);
    IF NOT EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Academic_Year=2026 AND Semester=1 AND Teacher_Id=3002 AND Class_Level=@lvl AND class_Letter='A' AND Subject_Id='ENG')  
        INSERT INTO Teacher_Class_Assignments (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level) VALUES (2026, 1, 3002, @lvl, 'A', 'ENG', @lvl);
    IF NOT EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Academic_Year=2026 AND Semester=1 AND Teacher_Id=3008 AND Class_Level=@lvl AND class_Letter='A' AND Subject_Id='SPO')  
        INSERT INTO Teacher_Class_Assignments (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level) VALUES (2026, 1, 3008, @lvl, 'A', 'SPO', @lvl);
    IF NOT EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Academic_Year=2026 AND Semester=1 AND Teacher_Id=3009 AND Class_Level=@lvl AND class_Letter='A' AND Subject_Id='ART')  
        INSERT INTO Teacher_Class_Assignments (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level) VALUES (2026, 1, 3009, @lvl, 'A', 'ART', @lvl);
    
    -- Assign ISLM to the dedicated teacher
    IF NOT EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Academic_Year=2026 AND Semester=1 AND Teacher_Id=3011 AND Class_Level=@lvl AND class_Letter='A' AND Subject_Id='ISLM')  
        INSERT INTO Teacher_Class_Assignments (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level) VALUES (2026, 1, 3011, @lvl, 'A', 'ISLM', @lvl);

    IF @lvl <= 3 BEGIN
        IF NOT EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Academic_Year=2026 AND Semester=1 AND Teacher_Id=3003 AND Class_Level=@lvl AND Subject_Id='MATH') 
            INSERT INTO Teacher_Class_Assignments (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level) VALUES (2026, 1, 3003, @lvl, 'A', 'MATH', @lvl);
        IF NOT EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Academic_Year=2026 AND Semester=1 AND Teacher_Id=3005 AND Class_Level=@lvl AND Subject_Id='SCI')  
            INSERT INTO Teacher_Class_Assignments (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level) VALUES (2026, 1, 3005, @lvl, 'A', 'SCI', @lvl);
    END

    IF @lvl >= 4 BEGIN
        IF NOT EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Academic_Year=2026 AND Semester=1 AND Teacher_Id=3004 AND Class_Level=@lvl AND Subject_Id='MATH') 
            INSERT INTO Teacher_Class_Assignments (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level) VALUES (2026, 1, 3004, @lvl, 'A', 'MATH', @lvl);
        IF NOT EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Academic_Year=2026 AND Semester=1 AND Teacher_Id=3006 AND Class_Level=@lvl AND Subject_Id='SCI')  
            INSERT INTO Teacher_Class_Assignments (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level) VALUES (2026, 1, 3006, @lvl, 'A', 'SCI', @lvl);
            
        IF NOT EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Academic_Year=2026 AND Semester=1 AND Teacher_Id=3007 AND Class_Level=@lvl AND Subject_Id='HIST') 
            INSERT INTO Teacher_Class_Assignments (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level) VALUES (2026, 1, 3007, @lvl, 'A', 'HIST', @lvl);
        IF NOT EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Academic_Year=2026 AND Semester=1 AND Teacher_Id=3007 AND Class_Level=@lvl AND Subject_Id='GEO')  
            INSERT INTO Teacher_Class_Assignments (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level) VALUES (2026, 1, 3007, @lvl, 'A', 'GEO', @lvl);
    END

    IF @lvl >= 5 BEGIN
        IF NOT EXISTS (SELECT 1 FROM Teacher_Class_Assignments WHERE Academic_Year=2026 AND Semester=1 AND Teacher_Id=3010 AND Class_Level=@lvl AND Subject_Id='COMP') 
            INSERT INTO Teacher_Class_Assignments (Academic_Year, Semester, Teacher_Id, Class_Level, class_Letter, Subject_Id, Course_Level) VALUES (2026, 1, 3010, @lvl, 'A', 'COMP', @lvl);
    END

    SET @lvl = @lvl + 1;
END
GO

----------------------------------------------
-- CLASS 1A (Level 1: 7 Subjects)
-- FIX: Parents (Relation->relationship, Profession->Occupation)
-- FIX: Student_Addresses (Address_Type->Main_Address)
----------------------------------------------
DECLARE @AddrId INT;

IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 101) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (101, N'محمود', N'الرفاعي', 'm.rifai@email.com', '0791000001', N'أب', N'مهندس');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 1 AND District = N'خلدا' AND Street = N'المدينة' AND Building_No = '10') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (1, N'خلدا', N'المدينة', '10');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 1 AND District = N'خلدا' AND Street = N'المدينة' AND Building_No = '10');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026101) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026101, N'زيد', N'الرفاعي', '2019-04-12', 'M', 'O+', NULL, 1, 'A', 101);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026101, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026101, 'ARAB', 1, 85, 88, 90, 89),
        (2026, 1, 2026101, 'ENG', 1, 78, 82, 85, 80),
        (2026, 1, 2026101, 'MATH', 1, 92, 95, 90, 94),
        (2026, 1, 2026101, 'SCI', 1, 88, 85, 87, 86),
        (2026, 1, 2026101, 'ART', 1, 95, 96, 95, 98),
        (2026, 1, 2026101, 'SPO', 1, 100, 98, 99, 100),
        (2026, 1, 2026101, 'ISLM', 1, 90, 92, 94, 91);
END

IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 102) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (102, N'سلوى', N'عيسى', 'salwa@email.com', '0791000002', N'أم', N'معلمة');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 2 AND District = N'الزرقاء' AND Street = N'مكة' AND Building_No = '15') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (2, N'الزرقاء', N'مكة', '15');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 2 AND District = N'الزرقاء' AND Street = N'مكة' AND Building_No = '15');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026102) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026102, N'لجين', N'ياسين', '2019-06-05', 'F', 'A-', NULL, 1, 'A', 102);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026102, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026102, 'ARAB', 1, 95, 96, 94, 98),
        (2026, 1, 2026102, 'ENG', 1, 92, 90, 95, 94),
        (2026, 1, 2026102, 'MATH', 1, 85, 88, 82, 86),
        (2026, 1, 2026102, 'SCI', 1, 90, 92, 89, 91),
        (2026, 1, 2026102, 'ART', 1, 98, 99, 95, 100),
        (2026, 1, 2026102, 'SPO', 1, 85, 86, 88, 90),
        (2026, 1, 2026102, 'ISLM', 1, 96, 95, 98, 97);
END

IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 103) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (103, N'رامي', N'حداد', 'rami@email.com', '0791000003', N'أب', N'محاسب');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 3 AND District = N'الحصن' AND Street = N'اليرموك' AND Building_No = '5') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (3, N'الحصن', N'اليرموك', '5');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 3 AND District = N'الحصن' AND Street = N'اليرموك' AND Building_No = '5');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026103) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026103, N'فارس', N'حداد', '2019-11-20', 'M', 'B+', NULL, 1, 'A', 103);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026103, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026103, 'ARAB', 1, 75, 78, 80, 77),
        (2026, 1, 2026103, 'ENG', 1, 88, 85, 86, 90),
        (2026, 1, 2026103, 'MATH', 1, 70, 75, 72, 78),
        (2026, 1, 2026103, 'SCI', 1, 80, 82, 85, 84),
        (2026, 1, 2026103, 'ART', 1, 85, 88, 86, 90),
        (2026, 1, 2026103, 'SPO', 1, 95, 92, 94, 96),
        (2026, 1, 2026103, 'ISLM', 1, 82, 85, 84, 88);
END

---------------------------------------------
-- CLASS 2A (Level 2: 7 Subjects)
---------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 104) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (104, N'جمال', N'الناصر', 'jamal@email.com', '0791000004', N'أب', N'طيار');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 1 AND District = N'دابوق' AND Street = N'الحسين' AND Building_No = '1') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (1, N'دابوق', N'الحسين', '1');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 1 AND District = N'دابوق' AND Street = N'الحسين' AND Building_No = '1');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026201) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026201, N'عالية', N'الناصر', '2018-02-14', 'F', 'AB+', NULL, 2, 'A', 104);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026201, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026201, 'ARAB', 2, 90, 92, 95, 94),
        (2026, 1, 2026201, 'ENG', 2, 95, 96, 98, 97),
        (2026, 1, 2026201, 'MATH', 2, 88, 90, 92, 89),
        (2026, 1, 2026201, 'SCI', 2, 92, 95, 94, 96),
        (2026, 1, 2026201, 'ART', 2, 98, 99, 100, 99),
        (2026, 1, 2026201, 'SPO', 2, 85, 88, 90, 89),
        (2026, 1, 2026201, 'ISLM', 2, 94, 95, 92, 96);
END

IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 105) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (105, N'حسن', N'المصري', 'hassan@email.com', '0791000005', N'أب', N'تاجر');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 9 AND District = N'العاشرة' AND Street = N'الشاطئ' AND Building_No = '22') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (9, N'العاشرة', N'الشاطئ', '22');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 9 AND District = N'العاشرة' AND Street = N'الشاطئ' AND Building_No = '22');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026202) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026202, N'يوسف', N'المصري', '2018-07-30', 'M', 'O-', N'حساسية', 2, 'A', 105);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026202, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026202, 'ARAB', 2, 80, 82, 85, 84),
        (2026, 1, 2026202, 'ENG', 2, 75, 78, 80, 76),
        (2026, 1, 2026202, 'MATH', 2, 85, 88, 86, 90),
        (2026, 1, 2026202, 'SCI', 2, 82, 85, 84, 88),
        (2026, 1, 2026202, 'ART', 2, 90, 92, 95, 94),
        (2026, 1, 2026202, 'SPO', 2, 95, 96, 98, 97),
        (2026, 1, 2026202, 'ISLM', 2, 85, 86, 88, 90);
END

IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 106) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (106, N'منى', N'سالم', 'mona@email.com', '0791000006', N'أم', N'طبيبة');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 4 AND District = N'السلط' AND Street = N'الستين' AND Building_No = '11') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (4, N'السلط', N'الستين', '11');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 4 AND District = N'السلط' AND Street = N'الستين' AND Building_No = '11');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026203) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026203, N'سارة', N'عودة', '2018-12-01', 'F', 'A+', NULL, 2, 'A', 106);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026203, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026203, 'ARAB', 2, 92, 94, 96, 95),
        (2026, 1, 2026203, 'ENG', 2, 90, 92, 95, 94),
        (2026, 1, 2026203, 'MATH', 2, 95, 98, 100, 99),
        (2026, 1, 2026203, 'SCI', 2, 94, 96, 95, 98),
        (2026, 1, 2026203, 'ART', 2, 95, 96, 98, 97),
        (2026, 1, 2026203, 'SPO', 2, 88, 90, 92, 89),
        (2026, 1, 2026203, 'ISLM', 2, 95, 98, 96, 100);
END

---------------------------------------------
-- CLASS 3A (Level 3: 7 Subjects)
---------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 107) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (107, N'كريم', N'شاهين', 'karim@email.com', '0791000007', N'أب', N'محامي');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 1 AND District = N'تلاع العلي' AND Street = N'الجاردنز' AND Building_No = '44') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (1, N'تلاع العلي', N'الجاردنز', '44');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 1 AND District = N'تلاع العلي' AND Street = N'الجاردنز' AND Building_No = '44');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026301) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026301, N'هادي', N'شاهين', '2017-03-10', 'M', 'B+', NULL, 3, 'A', 107);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026301, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026301, 'ARAB', 3, 85, 88, 90, 89),
        (2026, 1, 2026301, 'ENG', 3, 80, 82, 85, 84),
        (2026, 1, 2026301, 'MATH', 3, 88, 90, 92, 89),
        (2026, 1, 2026301, 'SCI', 3, 85, 86, 88, 90),
        (2026, 1, 2026301, 'ART', 3, 90, 92, 95, 94),
        (2026, 1, 2026301, 'SPO', 3, 95, 96, 98, 97),
        (2026, 1, 2026301, 'ISLM', 3, 92, 94, 96, 95);
END

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026302) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026302, N'فادي', N'شاهين', '2017-03-10', 'M', 'B+', NULL, 3, 'A', 107);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026302, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026302, 'ARAB', 3, 86, 89, 91, 88),
        (2026, 1, 2026302, 'ENG', 3, 82, 85, 84, 88),
        (2026, 1, 2026302, 'MATH', 3, 90, 92, 95, 94),
        (2026, 1, 2026302, 'SCI', 3, 88, 90, 92, 89),
        (2026, 1, 2026302, 'ART', 3, 92, 94, 96, 95),
        (2026, 1, 2026302, 'SPO', 3, 96, 98, 100, 99),
        (2026, 1, 2026302, 'ISLM', 3, 94, 95, 92, 96);
END

IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 108) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (108, N'فاطمة', N'خليل', 'fatima@email.com', '0791000008', N'أم', N'ربة منزل');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 11 AND District = N'جرش' AND Street = N'الرئيسي' AND Building_No = '7') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (11, N'جرش', N'الرئيسي', '7');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 11 AND District = N'جرش' AND Street = N'الرئيسي' AND Building_No = '7');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026303) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026303, N'مريم', N'خليل', '2017-08-22', 'F', 'O+', NULL, 3, 'A', 108);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026303, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026303, 'ARAB', 3, 98, 99, 100, 99),
        (2026, 1, 2026303, 'ENG', 3, 95, 96, 98, 97),
        (2026, 1, 2026303, 'MATH', 3, 92, 95, 94, 96),
        (2026, 1, 2026303, 'SCI', 3, 96, 98, 100, 99),
        (2026, 1, 2026303, 'ART', 3, 95, 98, 96, 100),
        (2026, 1, 2026303, 'SPO', 3, 85, 88, 90, 89),
        (2026, 1, 2026303, 'ISLM', 3, 100, 99, 98, 100);
END

---------------------------------------------
-- CLASS 4A (Level 4: 9 Subjects - Adds HIST, GEO)
---------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 109) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (109, N'طارق', N'نور', 'tariq@email.com', '0791000009', N'أب', N'مبرمج');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 1 AND District = N'الجبيهة' AND Street = N'الجامعة' AND Building_No = '12') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (1, N'الجبيهة', N'الجامعة', '12');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 1 AND District = N'الجبيهة' AND Street = N'الجامعة' AND Building_No = '12');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026401) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026401, N'لين', N'نور', '2016-01-15', 'F', 'A+', NULL, 4, 'A', 109);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026401, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026401, 'ARAB', 4, 92, 94, 96, 95),
        (2026, 1, 2026401, 'ENG', 4, 90, 92, 95, 94),
        (2026, 1, 2026401, 'MATH', 4, 88, 90, 92, 89),
        (2026, 1, 2026401, 'SCI', 4, 95, 96, 98, 97),
        (2026, 1, 2026401, 'ART', 4, 90, 92, 95, 94),
        (2026, 1, 2026401, 'SPO', 4, 85, 86, 88, 90),
        (2026, 1, 2026401, 'ISLM', 4, 96, 98, 100, 99),
        (2026, 1, 2026401, 'HIST', 4, 90, 92, 94, 95),
        (2026, 1, 2026401, 'GEO', 4, 88, 90, 92, 91);
END

IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 110) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (110, N'سامر', N'داود', 'samer@email.com', '0791000010', N'أب', N'ضابط');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 6 AND District = N'المزار' AND Street = N'الشهداء' AND Building_No = '2') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (6, N'المزار', N'الشهداء', '2');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 6 AND District = N'المزار' AND Street = N'الشهداء' AND Building_No = '2');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026402) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026402, N'علي', N'داود', '2016-05-18', 'M', 'AB-', NULL, 4, 'A', 110);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026402, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026402, 'ARAB', 4, 78, 80, 82, 85),
        (2026, 1, 2026402, 'ENG', 4, 75, 78, 80, 76),
        (2026, 1, 2026402, 'MATH', 4, 85, 88, 86, 90),
        (2026, 1, 2026402, 'SCI', 4, 82, 85, 84, 88),
        (2026, 1, 2026402, 'ART', 4, 88, 90, 92, 89),
        (2026, 1, 2026402, 'SPO', 4, 98, 99, 100, 99),
        (2026, 1, 2026402, 'ISLM', 4, 85, 88, 90, 89),
        (2026, 1, 2026402, 'HIST', 4, 72, 75, 78, 80),
        (2026, 1, 2026402, 'GEO', 4, 75, 78, 80, 82);
END

IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 111) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (111, N'رانية', N'عمر', 'rania@email.com', '0791000011', N'أم', N'صيدلانية');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 1 AND District = N'الصويفية' AND Street = N'الوكالات' AND Building_No = '8') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (1, N'الصويفية', N'الوكالات', '8');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 1 AND District = N'الصويفية' AND Street = N'الوكالات' AND Building_No = '8');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026403) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026403, N'دانا', N'عمر', '2016-11-30', 'F', 'O+', NULL, 4, 'A', 111);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026403, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026403, 'ARAB', 4, 95, 96, 98, 97),
        (2026, 1, 2026403, 'ENG', 4, 98, 99, 100, 99),
        (2026, 1, 2026403, 'MATH', 4, 90, 92, 95, 94),
        (2026, 1, 2026403, 'SCI', 4, 92, 94, 96, 95),
        (2026, 1, 2026403, 'ART', 4, 96, 98, 100, 99),
        (2026, 1, 2026403, 'SPO', 4, 88, 90, 92, 89),
        (2026, 1, 2026403, 'ISLM', 4, 95, 98, 96, 100),
        (2026, 1, 2026403, 'HIST', 4, 92, 95, 94, 96),
        (2026, 1, 2026403, 'GEO', 4, 94, 96, 95, 98);
END

----------------------------------------------
-- CLASS 5A (Level 5: 10 Subjects - Adds COMP)
----------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 112) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (112, N'ياسر', N'حمدان', 'yaser@email.com', '0791000012', N'أب', N'مدير');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 5 AND District = N'مادبا' AND Street = N'السلام' AND Building_No = '20') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (5, N'مادبا', N'السلام', '20');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 5 AND District = N'مادبا' AND Street = N'السلام' AND Building_No = '20');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026501) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026501, N'خالد', N'حمدان', '2015-02-28', 'M', 'B-', NULL, 5, 'A', 112);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026501, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026501, 'ARAB', 5, 82, 85, 84, 88),
        (2026, 1, 2026501, 'ENG', 5, 80, 82, 85, 84),
        (2026, 1, 2026501, 'MATH', 5, 85, 88, 86, 90),
        (2026, 1, 2026501, 'SCI', 5, 88, 90, 92, 89),
        (2026, 1, 2026501, 'ART', 5, 85, 86, 88, 90),
        (2026, 1, 2026501, 'SPO', 5, 95, 96, 98, 97),
        (2026, 1, 2026501, 'ISLM', 5, 88, 90, 92, 89),
        (2026, 1, 2026501, 'HIST', 5, 80, 82, 85, 84),
        (2026, 1, 2026501, 'GEO', 5, 82, 85, 84, 88),
        (2026, 1, 2026501, 'COMP', 5, 90, 92, 95, 94);
END

IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 113) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (113, N'أمل', N'غانم', 'amal@email.com', '0791000013', N'أم', N'مهندسة');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 10 AND District = N'المفرق' AND Street = N'الجيش' AND Building_No = '17') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (10, N'المفرق', N'الجيش', '17');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 10 AND District = N'المفرق' AND Street = N'الجيش' AND Building_No = '17');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026502) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026502, N'بشرى', N'غانم', '2015-06-11', 'F', 'A+', N'ربو', 5, 'A', 113);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026502, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026502, 'ARAB', 5, 95, 98, 96, 100),
        (2026, 1, 2026502, 'ENG', 5, 92, 94, 96, 95),
        (2026, 1, 2026502, 'MATH', 5, 98, 99, 100, 99),
        (2026, 1, 2026502, 'SCI', 5, 96, 98, 100, 99),
        (2026, 1, 2026502, 'ART', 5, 95, 96, 98, 97),
        (2026, 1, 2026502, 'SPO', 5, 88, 90, 92, 89),
        (2026, 1, 2026502, 'ISLM', 5, 98, 99, 100, 99),
        (2026, 1, 2026502, 'HIST', 5, 94, 96, 95, 98),
        (2026, 1, 2026502, 'GEO', 5, 95, 96, 98, 97),
        (2026, 1, 2026502, 'COMP', 5, 96, 98, 100, 99);
END

IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 114) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (114, N'سعد', N'محمود', 'saad@email.com', '0791000014', N'أب', N'صحفي');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 1 AND District = N'عبدون' AND Street = N'التاج' AND Building_No = '3') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (1, N'عبدون', N'التاج', '3');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 1 AND District = N'عبدون' AND Street = N'التاج' AND Building_No = '3');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026503) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026503, N'جاد', N'محمود', '2015-09-09', 'M', 'O-', NULL, 5, 'A', 114);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026503, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026503, 'ARAB', 5, 75, 78, 80, 76),
        (2026, 1, 2026503, 'ENG', 5, 85, 88, 86, 90),
        (2026, 1, 2026503, 'MATH', 5, 78, 80, 82, 85),
        (2026, 1, 2026503, 'SCI', 5, 80, 82, 85, 84),
        (2026, 1, 2026503, 'ART', 5, 82, 85, 84, 88),
        (2026, 1, 2026503, 'SPO', 5, 92, 94, 96, 95),
        (2026, 1, 2026503, 'ISLM', 5, 80, 82, 85, 84),
        (2026, 1, 2026503, 'HIST', 5, 75, 78, 80, 76),
        (2026, 1, 2026503, 'GEO', 5, 78, 80, 82, 85),
        (2026, 1, 2026503, 'COMP', 5, 85, 88, 86, 90);
END

----------------------------------------------
-- CLASS 6A (Level 6: 10 Subjects)
----------------------------------------------
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 1 AND District = N'الجبيهة' AND Street = N'الجامعة' AND Building_No = '12');
IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026601) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026601, N'ريان', N'نور', '2014-04-05', 'M', 'A+', NULL, 6, 'A', 109);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026601, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026601, 'ARAB', 6, 88, 90, 92, 89),
        (2026, 1, 2026601, 'ENG', 6, 92, 94, 96, 95),
        (2026, 1, 2026601, 'MATH', 6, 85, 86, 88, 90),
        (2026, 1, 2026601, 'SCI', 6, 90, 92, 95, 94),
        (2026, 1, 2026601, 'ART', 6, 95, 96, 98, 97),
        (2026, 1, 2026601, 'SPO', 6, 96, 98, 100, 99),
        (2026, 1, 2026601, 'ISLM', 6, 88, 90, 92, 89),
        (2026, 1, 2026601, 'HIST', 6, 85, 88, 86, 90),
        (2026, 1, 2026601, 'GEO', 6, 90, 92, 94, 95),
        (2026, 1, 2026601, 'COMP', 6, 92, 95, 94, 96);
END

IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 115) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (115, N'وسام', N'جابر', 'wesam@email.com', '0791000015', N'أب', N'مقاول');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 2 AND District = N'الرصيفة' AND Street = N'المحطة' AND Building_No = '9') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (2, N'الرصيفة', N'المحطة', '9');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 2 AND District = N'الرصيفة' AND Street = N'المحطة' AND Building_No = '9');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026602) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026602, N'كريم', N'جابر', '2014-08-14', 'M', 'B+', NULL, 6, 'A', 115);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026602, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026602, 'ARAB', 6, 70, 72, 75, 74),
        (2026, 1, 2026602, 'ENG', 6, 68, 70, 72, 75),
        (2026, 1, 2026602, 'MATH', 6, 85, 88, 86, 90),
        (2026, 1, 2026602, 'SCI', 6, 80, 82, 85, 84),
        (2026, 1, 2026602, 'ART', 6, 82, 85, 84, 88),
        (2026, 1, 2026602, 'SPO', 6, 90, 92, 95, 94),
        (2026, 1, 2026602, 'ISLM', 6, 75, 78, 80, 76),
        (2026, 1, 2026602, 'HIST', 6, 72, 75, 78, 80),
        (2026, 1, 2026602, 'GEO', 6, 70, 72, 75, 74),
        (2026, 1, 2026602, 'COMP', 6, 88, 90, 92, 89);
END

IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 116) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (116, N'ديما', N'فاروق', 'dima@email.com', '0791000016', N'أم', N'مصممة');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 7 AND District = N'الطفيلة' AND Street = N'القلعة' AND Building_No = '13') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (7, N'الطفيلة', N'القلعة', '13');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 7 AND District = N'الطفيلة' AND Street = N'القلعة' AND Building_No = '13');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026603) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026603, N'نور', N'فاروق', '2014-11-25', 'F', 'AB+', NULL, 6, 'A', 116);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026603, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026603, 'ARAB', 6, 95, 96, 98, 97),
        (2026, 1, 2026603, 'ENG', 6, 98, 99, 100, 99),
        (2026, 1, 2026603, 'MATH', 6, 90, 92, 95, 94),
        (2026, 1, 2026603, 'SCI', 6, 92, 94, 96, 95),
        (2026, 1, 2026603, 'ART', 6, 100, 98, 99, 100),
        (2026, 1, 2026603, 'SPO', 6, 88, 90, 92, 89),
        (2026, 1, 2026603, 'ISLM', 6, 96, 98, 100, 99),
        (2026, 1, 2026603, 'HIST', 6, 94, 96, 95, 98),
        (2026, 1, 2026603, 'GEO', 6, 95, 96, 98, 97),
        (2026, 1, 2026603, 'COMP', 6, 98, 99, 100, 99);
END

--------------------------------------------
-- CLASS 7A (Level 7: 10 Subjects)
--------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 117) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (117, N'باسم', N'الشيخ', 'basem@email.com', '0791000017', N'أب', N'أستاذ');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 3 AND District = N'اربد' AND Street = N'شفيق ارشيدات' AND Building_No = '40') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (3, N'اربد', N'شفيق ارشيدات', '40');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 3 AND District = N'اربد' AND Street = N'شفيق ارشيدات' AND Building_No = '40');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026701) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026701, N'سيف', N'الشيخ', '2013-01-10', 'M', 'O+', NULL, 7, 'A', 117);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026701, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026701, 'ARAB', 7, 94, 96, 95, 98),
        (2026, 1, 2026701, 'ENG', 7, 95, 96, 98, 97),
        (2026, 1, 2026701, 'MATH', 7, 98, 99, 100, 99),
        (2026, 1, 2026701, 'SCI', 7, 96, 98, 100, 99),
        (2026, 1, 2026701, 'ART', 7, 90, 92, 95, 94),
        (2026, 1, 2026701, 'SPO', 7, 95, 96, 98, 97),
        (2026, 1, 2026701, 'ISLM', 7, 98, 99, 100, 99),
        (2026, 1, 2026701, 'HIST', 7, 92, 94, 96, 95),
        (2026, 1, 2026701, 'GEO', 7, 90, 92, 95, 94),
        (2026, 1, 2026701, 'COMP', 7, 96, 98, 100, 99);
END

IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 118) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (118, N'نجوى', N'صالح', 'najwa@email.com', '0791000018', N'أم', N'محاسبة');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 8 AND District = N'معان' AND Street = N'الرواد' AND Building_No = '6') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (8, N'معان', N'الرواد', '6');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 8 AND District = N'معان' AND Street = N'الرواد' AND Building_No = '6');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026702) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026702, N'يارا', N'صالح', '2013-05-19', 'F', 'A-', NULL, 7, 'A', 118);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026702, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026702, 'ARAB', 7, 85, 88, 90, 89),
        (2026, 1, 2026702, 'ENG', 7, 88, 90, 92, 89),
        (2026, 1, 2026702, 'MATH', 7, 80, 82, 85, 84),
        (2026, 1, 2026702, 'SCI', 7, 85, 86, 88, 90),
        (2026, 1, 2026702, 'ART', 7, 90, 92, 95, 94),
        (2026, 1, 2026702, 'SPO', 7, 82, 85, 84, 88),
        (2026, 1, 2026702, 'ISLM', 7, 88, 90, 92, 89),
        (2026, 1, 2026702, 'HIST', 7, 85, 86, 88, 90),
        (2026, 1, 2026702, 'GEO', 7, 80, 82, 85, 84),
        (2026, 1, 2026702, 'COMP', 7, 88, 90, 92, 89);
END

IF NOT EXISTS (SELECT 1 FROM Parents WHERE Parental_Id = 119) INSERT INTO Parents (Parental_Id, First_name, Last_name, Email, Phone_Number, relationship, Occupation) VALUES (119, N'عمار', N'زياد', 'ammar@email.com', '0791000019', N'أب', N'مستشار');
IF NOT EXISTS (SELECT 1 FROM Address WHERE Gov_Id = 12 AND District = N'عجلون' AND Street = N'القلعة' AND Building_No = '33') INSERT INTO Address (Gov_Id, District, Street, Building_No) VALUES (12, N'عجلون', N'القلعة', '33');
SET @AddrId = (SELECT Address_Id FROM Address WHERE Gov_Id = 12 AND District = N'عجلون' AND Street = N'القلعة' AND Building_No = '33');

IF NOT EXISTS (SELECT 1 FROM Student WHERE Student_Id = 2026703) BEGIN
    INSERT INTO Student (Student_Id, First_Name, Last_Name, Date_of_Birth, Gender, Blood_Type, Medical_Conditions, Class_Level, class_Letter, Parental_Id) VALUES (2026703, N'يزن', N'زياد', '2013-09-02', 'M', 'B-', N'ضعف نظر', 7, 'A', 119);
    INSERT INTO Student_Addresses (Student_Id, Address_Id, Main_Address) VALUES (2026703, @AddrId, 1);
    
    INSERT INTO Student_Grades (Academic_Year, Semester, Student_Id, Subject_Id, Course_Level, First_Grade, Second_Grade, third_Grade, Final_Grade) VALUES 
        (2026, 1, 2026703, 'ARAB', 7, 78, 80, 82, 85),
        (2026, 1, 2026703, 'ENG', 7, 75, 78, 80, 76),
        (2026, 1, 2026703, 'MATH', 7, 70, 72, 75, 74),
        (2026, 1, 2026703, 'SCI', 7, 75, 78, 80, 82),
        (2026, 1, 2026703, 'ART', 7, 85, 88, 86, 90),
        (2026, 1, 2026703, 'SPO', 7, 90, 92, 95, 94),
        (2026, 1, 2026703, 'ISLM', 7, 80, 82, 85, 84),
        (2026, 1, 2026703, 'HIST', 7, 78, 80, 82, 85),
        (2026, 1, 2026703, 'GEO', 7, 75, 78, 80, 76),
        (2026, 1, 2026703, 'COMP', 7, 85, 88, 86, 90);
END
GO