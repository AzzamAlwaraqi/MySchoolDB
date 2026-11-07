# Build_Reports.ps1
# Generates the paginated .rdl reports in this folder, then (optionally) uploads them to SSRS.
#   .\Build_Reports.ps1            # just (re)write the .rdl files
#   .\Build_Reports.ps1 -Deploy    # write + publish to the report server
param([switch]$Deploy)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$DSRef = '/MYSchoolDS'            # shared data source already in the portal
$PortalFolder = '/SchoolReports'  # where the reports land in the portal
$ReportServer = 'http://localhost/ReportServer'

# --- tiny helpers ---------------------------------------------------------------------------
function XmlEsc([string]$s){ $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' }

# A <Field> list from column specs (plus any extra field names used only in expressions)
function FieldsXml($cols, $extra){
    $sb = "      <Fields>`n"
    foreach($c in $cols){
        $sb += "        <Field Name=`"$($c.F)`"><DataField>$($c.F)</DataField><rd:TypeName>$($c.T)</rd:TypeName></Field>`n"
    }
    foreach($e in $extra){
        $sb += "        <Field Name=`"$($e.F)`"><DataField>$($e.F)</DataField><rd:TypeName>$($e.T)</rd:TypeName></Field>`n"
    }
    $sb + "      </Fields>"
}

# A stored-proc dataset bound to the shared data source
function ProcDataSet($name, $proc, $paramsXml, $fieldsXml){
@"
    <DataSet Name="$name">
      <Query>
        <DataSourceName>SchoolDBDataSource</DataSourceName>
        <CommandType>StoredProcedure</CommandType>
        <CommandText>$proc</CommandText>
$paramsXml
      </Query>
$fieldsXml
    </DataSet>
"@
}

# One header textbox cell
function HeadCell($text){
@"
                    <TablixCell><CellContents>
                      <Textbox Name="h$([guid]::NewGuid().ToString('N').Substring(0,8))">
                        <CanGrow>true</CanGrow>
                        <Paragraphs><Paragraph><TextRuns><TextRun><Value>$(XmlEsc $text)</Value>
                          <Style><FontSize>10pt</FontSize><FontWeight>Bold</FontWeight><Color>White</Color></Style></TextRun></TextRuns></Paragraph></Paragraphs>
                        <Style><BackgroundColor>#2e5b8a</BackgroundColor><PaddingLeft>3pt</PaddingLeft><PaddingTop>2pt</PaddingTop><PaddingBottom>2pt</PaddingBottom>
                          <Border><Color>White</Color><Style>Solid</Style><Width>0.5pt</Width></Border></Style>
                      </Textbox>
                    </CellContents></TablixCell>
"@
}

# One detail textbox cell bound to a field
function DataCell($col, $tbName){
    $align = if($col.A){$col.A}else{'Left'}
@"
                    <TablixCell><CellContents>
                      <Textbox Name="$tbName">
                        <CanGrow>true</CanGrow>
                        <Paragraphs><Paragraph><TextRuns><TextRun><Value>=Fields!$($col.F).Value</Value>
                          <Style><FontSize>10pt</FontSize><Color>#222222</Color></Style></TextRun></TextRuns>
                          <Style><TextAlign>$align</TextAlign></Style></Paragraph></Paragraphs>
                        <Style><PaddingLeft>3pt</PaddingLeft><PaddingTop>2pt</PaddingTop><PaddingBottom>2pt</PaddingBottom>
                          <Border><Color>#cccccc</Color><Style>Solid</Style><Width>0.5pt</Width></Border></Style>
                      </Textbox>
                    </CellContents></TablixCell>
"@
}

# A simple header+detail table (Tablix) over a dataset
function TableTablix($name, $dataset, $cols, $top){
    $colsXml=''; foreach($c in $cols){ $colsXml += "                <TablixColumn><Width>$($c.W)</Width></TablixColumn>`n" }
    $headXml=''; foreach($c in $cols){ $headXml += (HeadCell $c.H) }
    $dataXml=''; $i=0
    foreach($c in $cols){ $i++; $dataXml += (DataCell $c ("d_"+$name+"_"+$i)) }
    $colMembers=''; foreach($c in $cols){ $colMembers += "                  <TablixMember />`n" }
    $width = 0.0; foreach($c in $cols){ $width += [double]($c.W -replace 'in','') }
@"
          <Tablix Name="$name">
            <TablixBody>
              <TablixColumns>
$colsXml              </TablixColumns>
              <TablixRows>
                <TablixRow><Height>0.28in</Height><TablixCells>
$headXml                </TablixCells></TablixRow>
                <TablixRow><Height>0.25in</Height><TablixCells>
$dataXml                </TablixCells></TablixRow>
              </TablixRows>
            </TablixBody>
            <TablixColumnHierarchy><TablixMembers>
$colMembers              </TablixMembers></TablixColumnHierarchy>
            <TablixRowHierarchy><TablixMembers>
                <TablixMember><KeepWithGroup>After</KeepWithGroup></TablixMember>
                <TablixMember><Group Name="g_$name" /><TablixMembers><TablixMember /></TablixMembers></TablixMember>
            </TablixMembers></TablixRowHierarchy>
            <DataSetName>$dataset</DataSetName>
            <Top>$top</Top><Left>0in</Left><Height>0.53in</Height><Width>${width}in</Width>
          </Tablix>
"@
}

# Title textbox
function TitleBox($text, $sub){
@"
          <Textbox Name="Title">
            <CanGrow>true</CanGrow>
            <Paragraphs>
              <Paragraph><TextRuns><TextRun><Value>$(XmlEsc $text)</Value><Style><FontFamily>Segoe UI Light</FontFamily><FontSize>22pt</FontSize><Color>#2e5b8a</Color></Style></TextRun></TextRuns></Paragraph>
              <Paragraph><TextRuns><TextRun><Value>$(XmlEsc $sub)</Value><Style><FontSize>10pt</FontSize><Color>#777777</Color></Style></TextRun></TextRuns></Paragraph>
            </Paragraphs>
            <Top>0in</Top><Left>0in</Left><Height>0.7in</Height><Width>6.5in</Width>
            <Style><Border><Style>None</Style></Border></Style>
          </Textbox>
"@
}

# The page footer (timestamp + page numbers)
$Footer = @"
      <Page>
        <PageFooter><Height>0.35in</Height><PrintOnFirstPage>true</PrintOnFirstPage><PrintOnLastPage>true</PrintOnLastPage>
          <ReportItems>
            <Textbox Name="ft"><CanGrow>true</CanGrow><Paragraphs><Paragraph><TextRuns><TextRun>
              <Value>=Globals!ExecutionTime</Value><Style><FontSize>8pt</FontSize><Color>#999999</Color></Style></TextRun></TextRuns></Paragraph></Paragraphs>
              <Top>0.08in</Top><Left>0in</Left><Height>0.2in</Height><Width>3in</Width><Style /></Textbox>
            <Textbox Name="pg"><CanGrow>true</CanGrow><Paragraphs><Paragraph><TextRuns><TextRun>
              <Value>=&quot;Page &quot; &amp; Globals!PageNumber &amp; &quot; / &quot; &amp; Globals!TotalPages</Value><Style><FontSize>8pt</FontSize><Color>#999999</Color></Style></TextRun></TextRuns>
              <Style><TextAlign>Right</TextAlign></Style></Paragraph></Paragraphs>
              <Top>0.08in</Top><Left>4in</Left><Height>0.2in</Height><Width>2.5in</Width><Style /></Textbox>
          </ReportItems>
          <Style><Border><Style>None</Style></Border></Style>
        </PageFooter>
        <LeftMargin>0.6in</LeftMargin><RightMargin>0.6in</RightMargin><TopMargin>0.5in</TopMargin><BottomMargin>0.5in</BottomMargin><Style /></Page>
"@

# Wrap body items into a full report document
function ReportDoc($datasetsXml, $bodyItems, $bodyHeight, $paramsXml, $paramLayout){
@"
<?xml version="1.0" encoding="utf-8"?>
<Report xmlns="http://schemas.microsoft.com/sqlserver/reporting/2016/01/reportdefinition" xmlns:rd="http://schemas.microsoft.com/SQLServer/reporting/reportdesigner">
  <AutoRefresh>0</AutoRefresh>
  <DataSources>
    <DataSource Name="SchoolDBDataSource">
      <DataSourceReference>$DSRef</DataSourceReference>
      <rd:SecurityType>None</rd:SecurityType>
    </DataSource>
  </DataSources>
  <DataSets>
$datasetsXml
  </DataSets>
  <ReportSections>
    <ReportSection>
      <Body>
        <ReportItems>
$bodyItems
        </ReportItems>
        <Height>$bodyHeight</Height>
        <Style><Border><Style>None</Style></Border></Style>
      </Body>
      <Width>7in</Width>
$Footer
    </ReportSection>
  </ReportSections>
$paramsXml
$paramLayout
</Report>
"@
}

# Student / Teacher picker parameter (dropdown from a list proc)
function PickerParam($pname, $listDs, $valField, $labelField, $prompt, $default){
@"
  <ReportParameters>
    <ReportParameter Name="$pname">
      <DataType>Integer</DataType>
      <Prompt>$prompt</Prompt>
      <ValidValues><DataSetReference><DataSetName>$listDs</DataSetName><ValueField>$valField</ValueField><LabelField>$labelField</LabelField></DataSetReference></ValidValues>
      <DefaultValue><Values><Value>$default</Value></Values></DefaultValue>
    </ReportParameter>
  </ReportParameters>
"@
}
$PLayout = "  <ReportParametersLayout><GridLayoutDefinition><NumberOfColumns>2</NumberOfColumns><NumberOfRows>1</NumberOfRows><CellDefinitions><CellDefinition><ColumnIndex>0</ColumnIndex><RowIndex>0</RowIndex><ParameterName>%%PNAME%%</ParameterName></CellDefinition></CellDefinitions></GridLayoutDefinition></ReportParametersLayout>"

$studentParamXml = "        <QueryParameters><QueryParameter Name=`"@Student_Id`"><Value>=Parameters!Student_Id.Value</Value></QueryParameter></QueryParameters>"
$teacherParamXml = "        <QueryParameters><QueryParameter Name=`"@Teacher_Id`"><Value>=Parameters!Teacher_Id.Value</Value></QueryParameter></QueryParameters>"

$studentListDs = ProcDataSet 'dsStudents' 'rpt_StudentList' '' (FieldsXml @(@{F='Student_Id';T='System.Int32'},@{F='Display_Name';T='System.String'}) $null)
$teacherListDs = ProcDataSet 'dsTeachers' 'rpt_TeacherList' '' (FieldsXml @(@{F='Teacher_Id';T='System.Int32'},@{F='Display_Name';T='System.String'}) $null)

# ============================================================================================
# 1) Student Schedule  (parameterized)
# ============================================================================================
$cols = @(
  @{F='Academic_Year';H='Year';   T='System.Int16'; W='0.6in'; A='Center'},
  @{F='Semester';     H='Sem';    T='System.Byte';  W='0.45in'; A='Center'},
  @{F='Subject_Name_En';H='Subject';T='System.String';W='1.5in';A='Left'},
  @{F='Subject_Name_Ar';H='Subject (AR)'; T='System.String';W='1.3in';A='Right'},
  @{F='Course_Level';  H='Level'; T='System.Byte';  W='0.55in'; A='Center'},
  @{F='Teacher_Name';  H='Teacher';T='System.String';W='1.45in';A='Left'},
  @{F='Class_Name';    H='Class'; T='System.String';W='0.7in'; A='Center'}
)
$ds = (ProcDataSet 'dsSchedule' 'rpt_StudentSchedule' $studentParamXml (FieldsXml $cols $null)) + "`n" + $studentListDs
$body = (TitleBox 'Student Schedule' '="Subjects and teachers for student #" & Parameters!Student_Id.Value') + (TableTablix 'tSched' 'dsSchedule' $cols '0.9in')
$rdl = ReportDoc $ds $body '2.2in' (PickerParam 'Student_Id' 'dsStudents' 'Student_Id' 'Display_Name' 'Student' '2026501') ($PLayout -replace '%%PNAME%%','Student_Id')
Set-Content -Path (Join-Path $here 'StudentSchedule.rdl') -Value $rdl -Encoding UTF8
Write-Host "wrote StudentSchedule.rdl"

# ============================================================================================
# 2) Teacher Schedule  (parameterized)  -> existing rpt_TeacherSchedule
# ============================================================================================
$cols = @(
  @{F='Academic_Year';H='Year'; T='System.Int16'; W='0.9in'; A='Center'},
  @{F='Semester';     H='Sem';  T='System.Byte';  W='0.7in'; A='Center'},
  @{F='Subject_Name_En';H='Subject';T='System.String';W='2.2in';A='Left'},
  @{F='Class_Level';  H='Class Level';T='System.Byte';W='1.1in';A='Center'},
  @{F='class_Letter'; H='Section';T='System.String';W='0.9in';A='Center'},
  @{F='Course_Level'; H='Course Level';T='System.Byte';W='1.1in';A='Center'}
)
$ds = (ProcDataSet 'dsTSched' 'rpt_TeacherSchedule' $teacherParamXml (FieldsXml $cols $null)) + "`n" + $teacherListDs
$body = (TitleBox 'Teacher Schedule' '="Classes taught by teacher #" & Parameters!Teacher_Id.Value') + (TableTablix 'tTSched' 'dsTSched' $cols '0.9in')
$rdl = ReportDoc $ds $body '2.2in' (PickerParam 'Teacher_Id' 'dsTeachers' 'Teacher_Id' 'Display_Name' 'Teacher' '3007') ($PLayout -replace '%%PNAME%%','Teacher_Id')
Set-Content -Path (Join-Path $here 'TeacherSchedule.rdl') -Value $rdl -Encoding UTF8
Write-Host "wrote TeacherSchedule.rdl"

# ============================================================================================
# 3) Student Marks  (parameterized) -> rpt_StudentReportCard_Lines  [drill-through / subreport target]
# ============================================================================================
$cols = @(
  @{F='Subject_Name_En';H='Subject';T='System.String';W='2.0in';A='Left'},
  @{F='Course_Level'; H='Level';T='System.Byte';W='0.7in';A='Center'},
  @{F='First_Grade';  H='G1'; T='System.Int32';W='0.6in';A='Center'},
  @{F='Second_Grade'; H='G2'; T='System.Int32';W='0.6in';A='Center'},
  @{F='third_Grade';  H='G3'; T='System.Int32';W='0.6in';A='Center'},
  @{F='Final_Grade';  H='Final';T='System.Int32';W='0.7in';A='Center'},
  @{F='Subject_Average';H='Average';T='System.Decimal';W='0.9in';A='Center'}
)
$ds = ProcDataSet 'dsMarks' 'rpt_StudentReportCard_Lines' $studentParamXml (FieldsXml $cols $null)
$ds += "`n" + $studentListDs
$body = (TitleBox 'Student Marks' '="Full marks for student #" & Parameters!Student_Id.Value') + (TableTablix 'tMarks' 'dsMarks' $cols '0.9in')
$rdl = ReportDoc $ds $body '2.2in' (PickerParam 'Student_Id' 'dsStudents' 'Student_Id' 'Display_Name' 'Student' '2026501') ($PLayout -replace '%%PNAME%%','Student_Id')
Set-Content -Path (Join-Path $here 'StudentMarks.rdl') -Value $rdl -Encoding UTF8
Write-Host "wrote StudentMarks.rdl"

# ============================================================================================
# 4) Student Address  (parameterized) -> rpt_StudentAddress   [drill-through target]
# ============================================================================================
$cols = @(
  @{F='Gov_Name_En';H='Governorate';T='System.String';W='1.4in';A='Left'},
  @{F='District';   H='District';   T='System.String';W='1.5in';A='Left'},
  @{F='Street';     H='Street';     T='System.String';W='1.6in';A='Left'},
  @{F='Building_No';H='Building';    T='System.String';W='1.0in';A='Center'},
  @{F='Main_Address';H='Main?';      T='System.Boolean';W='0.9in';A='Center'}
)
$ds = ProcDataSet 'dsAddr' 'rpt_StudentAddress' $studentParamXml (FieldsXml $cols $null)
$ds += "`n" + $studentListDs
$body = (TitleBox 'Student Address' '="Addresses on file for student #" & Parameters!Student_Id.Value') + (TableTablix 'tAddr' 'dsAddr' $cols '0.9in')
$rdl = ReportDoc $ds $body '2.2in' (PickerParam 'Student_Id' 'dsStudents' 'Student_Id' 'Display_Name' 'Student' '2026501') ($PLayout -replace '%%PNAME%%','Student_Id')
Set-Content -Path (Join-Path $here 'StudentAddress.rdl') -Value $rdl -Encoding UTF8
Write-Host "wrote StudentAddress.rdl"

# ============================================================================================
# 5) Student Details  (parameterized MASTER) -> rpt_StudentDetails
#    Demonstrates a SUBREPORT (Student Marks inline) and a DRILL-THROUGH (to Student Address).
# ============================================================================================
$detFields = @(
  @{F='First_Name';T='System.String'},@{F='Last_Name';T='System.String'},@{F='Age';T='System.Int32'},
  @{F='Gender';T='System.String'},@{F='Blood_Type';T='System.String'},@{F='Medical_Conditions';T='System.String'},
  @{F='Class_Name';T='System.String'},@{F='Parent_Name';T='System.String'},@{F='relationship';T='System.String'},
  @{F='Parent_Phone';T='System.String'},@{F='Parent_Email';T='System.String'},@{F='Occupation';T='System.String'},
  @{F='GPA';T='System.Decimal'},@{F='Class_Rank';T='System.Int32'},@{F='Student_Id';T='System.Int32'}
)
$dsDet = ProcDataSet 'dsDetails' 'rpt_StudentDetails' $studentParamXml (FieldsXml $detFields $null)
$dsDet += "`n" + $studentListDs

# A labelled field line: a label textbox + a value textbox bound via First(...,"dsDetails")
function InfoRow($label, $expr, $top){
@"
          <Textbox Name="lbl$([guid]::NewGuid().ToString('N').Substring(0,6))">
            <CanGrow>true</CanGrow><Paragraphs><Paragraph><TextRuns><TextRun><Value>$(XmlEsc $label)</Value>
              <Style><FontSize>9pt</FontSize><FontWeight>Bold</FontWeight><Color>#2e5b8a</Color></Style></TextRun></TextRuns></Paragraph></Paragraphs>
            <Top>$top</Top><Left>0in</Left><Height>0.22in</Height><Width>1.6in</Width><Style /></Textbox>
          <Textbox Name="val$([guid]::NewGuid().ToString('N').Substring(0,6))">
            <CanGrow>true</CanGrow><Paragraphs><Paragraph><TextRuns><TextRun><Value>$(XmlEsc $expr)</Value>
              <Style><FontSize>9pt</FontSize><Color>#222222</Color></Style></TextRun></TextRuns></Paragraph></Paragraphs>
            <Top>$top</Top><Left>1.7in</Left><Height>0.22in</Height><Width>4.6in</Width><Style /></Textbox>
"@
}

$info  = (TitleBox 'Student Details' '=First(Fields!First_Name.Value,"dsDetails") & " " & First(Fields!Last_Name.Value,"dsDetails")')
$info += (InfoRow 'Student ID'   '=First(Fields!Student_Id.Value,"dsDetails")' '0.8in')
$info += (InfoRow 'Class'        '=First(Fields!Class_Name.Value,"dsDetails")' '1.05in')
$info += (InfoRow 'Age / Gender' '=First(Fields!Age.Value,"dsDetails") & "  /  " & First(Fields!Gender.Value,"dsDetails")' '1.30in')
$info += (InfoRow 'Blood Type'   '=First(Fields!Blood_Type.Value,"dsDetails")' '1.55in')
$info += (InfoRow 'Medical'      '=IIF(IsNothing(First(Fields!Medical_Conditions.Value,"dsDetails")),"-",First(Fields!Medical_Conditions.Value,"dsDetails"))' '1.80in')
$info += (InfoRow 'Parent'       '=First(Fields!Parent_Name.Value,"dsDetails") & " (" & First(Fields!relationship.Value,"dsDetails") & ")"' '2.05in')
$info += (InfoRow 'Parent Phone' '=First(Fields!Parent_Phone.Value,"dsDetails")' '2.30in')
$info += (InfoRow 'Parent Email' '=First(Fields!Parent_Email.Value,"dsDetails")' '2.55in')
$info += (InfoRow 'Occupation'   '=First(Fields!Occupation.Value,"dsDetails")' '2.80in')
$info += (InfoRow 'GPA'          '=First(Fields!GPA.Value,"dsDetails")' '3.05in')
$info += (InfoRow 'Class Rank'   '=First(Fields!Class_Rank.Value,"dsDetails")' '3.30in')

# Drill-through link to the Student Address report (same folder, relative name)
$drill = @"
          <Textbox Name="DrillAddress">
            <CanGrow>true</CanGrow><Paragraphs><Paragraph><TextRuns><TextRun><Value>View address report &#187;</Value>
              <Style><FontSize>10pt</FontSize><FontWeight>Bold</FontWeight><Color>#1a73e8</Color><TextDecoration>Underline</TextDecoration></Style>
              <ActionInfo><Actions><Action><Drillthrough><ReportName>StudentAddress</ReportName>
                <Parameters><Parameter Name="Student_Id"><Value>=Parameters!Student_Id.Value</Value></Parameter></Parameters>
              </Drillthrough></Action></Actions></ActionInfo></TextRun></TextRuns></Paragraph></Paragraphs>
            <Top>3.7in</Top><Left>0in</Left><Height>0.25in</Height><Width>3in</Width><Style /></Textbox>
"@

# Section label for the subreport
$subLabel = @"
          <Textbox Name="MarksLabel">
            <CanGrow>true</CanGrow><Paragraphs><Paragraph><TextRuns><TextRun><Value>Marks (all subjects)</Value>
              <Style><FontSize>12pt</FontSize><FontWeight>Bold</FontWeight><Color>#2e5b8a</Color></Style></TextRun></TextRuns></Paragraph></Paragraphs>
            <Top>4.15in</Top><Left>0in</Left><Height>0.3in</Height><Width>4in</Width><Style /></Textbox>
"@

# Subreport: embed Student Marks, passing the same Student_Id
$sub = @"
          <Subreport Name="MarksSub">
            <ReportName>StudentMarks</ReportName>
            <Parameters><Parameter Name="Student_Id"><Value>=Parameters!Student_Id.Value</Value></Parameter></Parameters>
            <Top>4.5in</Top><Left>0in</Left><Height>1.6in</Height><Width>6.5in</Width>
            <Style><Border><Style>None</Style></Border></Style>
          </Subreport>
"@

$body = $info + $drill + $subLabel + $sub
$rdl = ReportDoc $dsDet $body '6.2in' (PickerParam 'Student_Id' 'dsStudents' 'Student_Id' 'Display_Name' 'Student' '2026501') ($PLayout -replace '%%PNAME%%','Student_Id')
Set-Content -Path (Join-Path $here 'StudentDetails.rdl') -Value $rdl -Encoding UTF8
Write-Host "wrote StudentDetails.rdl"

# ============================================================================================
# 6) Students by Class  (DRILL-DOWN: each class header toggles its students open/closed)
# ============================================================================================
$cbCols = @(
  @{F='Student_Id';  H='ID';     T='System.Int32'; W='0.9in'; A='Center'},
  @{F='Student_Name';H='Student';T='System.String';W='2.8in'; A='Left'},
  @{F='Gender';      H='Gender'; T='System.String';W='0.8in'; A='Center'},
  @{F='GPA';         H='GPA';    T='System.Decimal';W='0.9in';A='Center'}
)
$cbExtra = @(@{F='Class_Name';T='System.String'},@{F='Class_Level';T='System.Byte'},@{F='class_Letter';T='System.String'})
$dsCB = ProcDataSet 'dsByClass' 'rpt_StudentsByClass' '' (FieldsXml $cbCols $cbExtra)

$cbColDefs=''; foreach($c in $cbCols){ $cbColDefs += "                <TablixColumn><Width>$($c.W)</Width></TablixColumn>`n" }
$cbHead='';   foreach($c in $cbCols){ $cbHead   += (HeadCell $c.H) }
$cbDetail=''; $j=0; foreach($c in $cbCols){ $j++; $cbDetail += (DataCell $c ("d_cb_"+$j)) }

# the collapsible class header row: 4 cells (toggle textbox + 3 matching band cells)
function BandCell(){
@"
                    <TablixCell><CellContents>
                      <Textbox Name="band$([guid]::NewGuid().ToString('N').Substring(0,8))">
                        <CanGrow>true</CanGrow><Paragraphs><Paragraph><TextRuns><TextRun><Value></Value><Style /></TextRun></TextRuns></Paragraph></Paragraphs>
                        <Style><BackgroundColor>#eaf0f7</BackgroundColor><Border><Color>#cccccc</Color><Style>Solid</Style><Width>0.5pt</Width></Border></Style>
                      </Textbox>
                    </CellContents></TablixCell>
"@
}
$cbGroupRow = @"
                    <TablixCell><CellContents>
                      <Textbox Name="ClassHeader">
                        <CanGrow>true</CanGrow>
                        <Paragraphs><Paragraph><TextRuns><TextRun><Value>=&quot;Class &quot; &amp; Fields!Class_Name.Value &amp; &quot;   -   &quot; &amp; Count(Fields!Student_Id.Value) &amp; &quot; student(s)&quot;</Value>
                          <Style><FontSize>11pt</FontSize><FontWeight>Bold</FontWeight><Color>#2e5b8a</Color></Style></TextRun></TextRuns></Paragraph></Paragraphs>
                        <ToggleImage><InitialState>false</InitialState></ToggleImage>
                        <Style><BackgroundColor>#eaf0f7</BackgroundColor><PaddingLeft>3pt</PaddingLeft><PaddingTop>3pt</PaddingTop><PaddingBottom>3pt</PaddingBottom>
                          <Border><Color>#cccccc</Color><Style>Solid</Style><Width>0.5pt</Width></Border></Style>
                      </Textbox>
                    </CellContents></TablixCell>
$(BandCell)$(BandCell)$(BandCell)
"@

$cbTablix = @"
          <Tablix Name="tByClass">
            <TablixBody>
              <TablixColumns>
$cbColDefs              </TablixColumns>
              <TablixRows>
                <TablixRow><Height>0.28in</Height><TablixCells>
$cbHead                </TablixCells></TablixRow>
                <TablixRow><Height>0.3in</Height><TablixCells>
$cbGroupRow                </TablixCells></TablixRow>
                <TablixRow><Height>0.25in</Height><TablixCells>
$cbDetail                </TablixCells></TablixRow>
              </TablixRows>
            </TablixBody>
            <TablixColumnHierarchy><TablixMembers>
                  <TablixMember /><TablixMember /><TablixMember /><TablixMember />
            </TablixMembers></TablixColumnHierarchy>
            <TablixRowHierarchy><TablixMembers>
                <TablixMember><KeepWithGroup>After</KeepWithGroup></TablixMember>
                <TablixMember>
                  <Group Name="ClassGroup"><GroupExpressions><GroupExpression>=Fields!Class_Name.Value</GroupExpression></GroupExpressions></Group>
                  <SortExpressions><SortExpression><Value>=Fields!Class_Level.Value</Value></SortExpression><SortExpression><Value>=Fields!class_Letter.Value</Value></SortExpression></SortExpressions>
                  <TablixMembers>
                    <TablixMember><KeepWithGroup>After</KeepWithGroup></TablixMember>
                    <TablixMember>
                      <Group Name="ClassDetail" />
                      <SortExpressions><SortExpression><Value>=Fields!Student_Name.Value</Value></SortExpression></SortExpressions>
                      <Visibility><Hidden>true</Hidden><ToggleItem>ClassHeader</ToggleItem></Visibility>
                      <TablixMembers><TablixMember /></TablixMembers>
                    </TablixMember>
                  </TablixMembers>
                </TablixMember>
            </TablixMembers></TablixRowHierarchy>
            <DataSetName>dsByClass</DataSetName>
            <Top>0.9in</Top><Left>0in</Left><Height>0.83in</Height><Width>5.4in</Width>
          </Tablix>
"@

$body = (TitleBox 'Students by Class' 'Click a class to expand or collapse its students') + $cbTablix
$rdl = ReportDoc $dsCB $body '3in' '' ''
Set-Content -Path (Join-Path $here 'StudentsByClass.rdl') -Value $rdl -Encoding UTF8
Write-Host "wrote StudentsByClass.rdl"

# ============================================================================================
# Optional publish to SSRS
# ============================================================================================
if($Deploy){
    $proxy = New-WebServiceProxy -Uri "$ReportServer/ReportService2010.asmx" -UseDefaultCredential
    $ns = $proxy.GetType().Namespace
    # ensure folder
    try { $proxy.CreateFolder((Split-Path $PortalFolder -Leaf), '/', $null) } catch {}
    foreach($f in 'StudentSchedule','TeacherSchedule','StudentMarks','StudentAddress','StudentDetails','StudentsByClass'){
        $bytes = [IO.File]::ReadAllBytes((Join-Path $here "$f.rdl"))
        $warnings = $null
        $proxy.CreateCatalogItem('Report', $f, $PortalFolder, $true, $bytes, $null, [ref]$warnings) | Out-Null
        if($warnings){ foreach($w in $warnings){ Write-Host "  [warn] $f : $($w.Message)" } }
        Write-Host "published $f"
    }
    Write-Host "Done. Open $ReportServer -> $PortalFolder"
}

