-- Sample payloads for the import layer. Run top to bottom on a fresh DB (after the schema,
-- SPs, triggers, functions and ImportXML_JSON are in place). Tests run in order on purpose -
-- the later ones lean on rows the earlier ones create.
USE MYSchoolDB;
GO

DECLARE @m VARCHAR(400), @e VARCHAR(400);

-- TEST 1 - JSON, the easy stuff first: subjects, teachers, a class, a parent. No FKs yet.
DECLARE @json1 NVARCHAR(MAX) = N'
{
  "Subjects": [
    { "Subject_Id": "PHY", "Subject_Name_Ar": "الفيزياء", "Subject_Name_En": "Physics",   "Required_Level": 7 },
    { "Subject_Id": "CHEM","Subject_Name_Ar": "الكيمياء", "Subject_Name_En": "Chemistry", "Required_Level": 8 }
  ],
  "Teacher": [
    { "Teacher_Id": 3101, "First_name": "نور",  "Last_name": "الديب", "Email": "noor@school.jo",  "Phone_Number": "0793100001", "specialization": "فيزياء", "qualification": "ماجستير" },
    { "Teacher_Id": 3102, "First_name": "كريم", "Last_name": "حداد",  "Email": "karim@school.jo", "Phone_Number": "0793100002", "specialization": "كيمياء", "qualification": "بكالوريوس" }
  ],
  "Classes": [
    { "Class_Level": 8, "class_Letter": "A", "Student_Capacity": 30, "Room_Number": "801" }
  ],
  "Parents": [
    { "Parental_Id": 5101, "First_name": "سمير", "Last_name": "خوري", "Email": "samir.k@mail.jo", "Phone_Number": "0795100001", "relationship": "أب", "Occupation": "مهندس" }
  ]
}';
EXEC usp_Import_JSON @Payload=@json1, @Result_Message=@m OUTPUT, @Error_Message=@e OUTPUT;
SELECT @m AS [JSON Test1 Result], @e AS [JSON Test1 Error];
GO

-- TEST 2 - JSON, the rows that hang off Test 1: courses, a student, address + link,
-- assignments, grades. Student is Class_Level 8 and grades are Course_Level 8 - they must
-- match or trg_StudentGrades_LevelMatch throws 50002.
DECLARE @m VARCHAR(400), @e VARCHAR(400);
DECLARE @json2 NVARCHAR(MAX) = N'
{
  "Courses": [
    { "Subject_Id": "PHY",  "Course_Level": 8, "Learning_Materials": "Physics Book 8",   "Description": "فيزياء للصف الثامن" },
    { "Subject_Id": "CHEM", "Course_Level": 8, "Learning_Materials": "Chemistry Book 8", "Description": "كيمياء للصف الثامن" }
  ],
  "Addresses": [
    { "Gov_Id": 1, "District": "خلدا", "Street": "وصفي التل", "Building_No": "22" }
  ],
  "Students": [
    { "Student_Id": 2026801, "First_Name": "ليان", "Last_Name": "خوري", "Date_of_Birth": "2012-05-01", "Gender": "F", "Blood_Type": "O+", "Class_Level": 8, "class_Letter": "A", "Parental_Id": 5101 }
  ],
  "Student_Addresses": [
    { "Student_Id": 2026801, "Address_Id": 1, "Main_Address": 1 }
  ],
  "Assignments": [
    { "Academic_Year": 2026, "Semester": 1, "Teacher_Id": 3101, "Class_Level": 8, "class_Letter": "A", "Subject_Id": "PHY",  "Course_Level": 8 },
    { "Academic_Year": 2026, "Semester": 1, "Teacher_Id": 3102, "Class_Level": 8, "class_Letter": "A", "Subject_Id": "CHEM", "Course_Level": 8 }
  ],
  "Grades": [
    { "Academic_Year": 2026, "Semester": 1, "Student_Id": 2026801, "Subject_Id": "PHY",  "Course_Level": 8, "First_Grade": 88, "Second_Grade": 90, "third_Grade": 85, "Final_Grade": 92 },
    { "Academic_Year": 2026, "Semester": 1, "Student_Id": 2026801, "Subject_Id": "CHEM", "Course_Level": 8, "First_Grade": 75, "Second_Grade": 80, "third_Grade": 78, "Final_Grade": 84 }
  ]
}';
-- Note: the link assumes the address above landed as Address_Id = 1 (true only on a fresh
-- Address table). Otherwise import Addresses first, read the real id back, then link.
EXEC usp_Import_JSON @Payload=@json2, @Result_Message=@m OUTPUT, @Error_Message=@e OUTPUT;
SELECT @m AS [JSON Test2 Result], @e AS [JSON Test2 Error];
GO

-- TEST 3 - same idea in XML. Root <MySchoolImport>, one attribute per column. A self-
-- contained Level-9 slice (subject, teacher, class, parent, course, student, assignment, grade).
DECLARE @m VARCHAR(400), @e VARCHAR(400);
DECLARE @xml NVARCHAR(MAX) = N'
<MySchoolImport>
  <Subjects>
    <Subject Subject_Id="BIO" Subject_Name_Ar="الأحياء" Subject_Name_En="Biology" Required_Level="9" />
  </Subjects>
  <Teachers>
    <Teacher Teacher_Id="3201" First_name="رانيا" Last_name="عيد" Email="rania@school.jo" Phone_Number="0793200001" specialization="أحياء" qualification="ماجستير" />
  </Teachers>
  <Classes>
    <Class Class_Level="9" class_Letter="A" Student_Capacity="28" Room_Number="901" />
  </Classes>
  <Parents>
    <Parent Parental_Id="5201" First_name="هاني" Last_name="عيد" Email="hani.e@mail.jo" Phone_Number="0795200001" relationship="أب" Occupation="طبيب" />
  </Parents>
  <Courses>
    <Course Subject_Id="BIO" Course_Level="9" Learning_Materials="Biology Book 9" Description="أحياء للصف التاسع" />
  </Courses>
  <Students>
    <Student Student_Id="2026901" First_Name="عمر" Last_Name="عيد" Date_of_Birth="2011-09-15" Gender="M" Blood_Type="A+" Class_Level="9" class_Letter="A" Parental_Id="5201" />
  </Students>
  <Assignments>
    <Assignment Academic_Year="2026" Semester="1" Teacher_Id="3201" Class_Level="9" class_Letter="A" Subject_Id="BIO" Course_Level="9" />
  </Assignments>
  <Grades>
    <Grade Academic_Year="2026" Semester="1" Student_Id="2026901" Subject_Id="BIO" Course_Level="9" First_Grade="91" Second_Grade="87" third_Grade="93" Final_Grade="95" />
  </Grades>
</MySchoolImport>';
EXEC usp_Import_XML @Payload=@xml, @Result_Message=@m OUTPUT, @Error_Message=@e OUTPUT;
SELECT @m AS [XML Test3 Result], @e AS [XML Test3 Error];
GO

-- TEST 4 - make sure bad data bounces. Three rows that should all fail, expect
-- "0 succeeded, 3 failed":
--   - Parental_Id 9999       -> Student_SP's parent-exists check stops it.
--   - PHY assignment level 5 -> no PHY course at level 5, so Assignment_SP rejects it first.
--   - PHY grade level 7      -> no PHY course at level 7, so StudentGrade_SP rejects it first.
-- (The SP checks fire before the triggers, but a real level-5/level-7 PHY would also trip
--  trg_Assignment_RequiredLevel 50003 / trg_StudentGrades_LevelMatch 50002.)
DECLARE @m VARCHAR(400), @e VARCHAR(400);
DECLARE @bad NVARCHAR(MAX) = N'
{
  "Students": [
    { "Student_Id": 2026802, "First_Name": "بدون", "Last_Name": "والد", "Date_of_Birth": "2012-01-01", "Gender": "M", "Class_Level": 8, "class_Letter": "A", "Parental_Id": 9999 }
  ],
  "Assignments": [
    { "Academic_Year": 2026, "Semester": 1, "Teacher_Id": 3101, "Class_Level": 8, "class_Letter": "A", "Subject_Id": "PHY", "Course_Level": 5 }
  ],
  "Grades": [
    { "Academic_Year": 2026, "Semester": 1, "Student_Id": 2026801, "Subject_Id": "PHY", "Course_Level": 7, "First_Grade": 50, "Second_Grade": 50, "third_Grade": 50, "Final_Grade": 50 }
  ]
}';
EXEC usp_Import_JSON @Payload=@bad, @Result_Message=@m OUTPUT, @Error_Message=@e OUTPUT;
SELECT @m AS [Negative Result], @e AS [Negative Error];   -- expect "0 succeeded, 3 failed"
GO

-- Audit trail: every row above, good or bad, should have left a line in Operation_Log.
SELECT TOP 40 Log_Id, Log_DateTime, Table_Name, Operation_Type, Record_Key, Status, Result_Message, Error_Message
FROM Operation_Log ORDER BY Log_Id DESC;
GO
