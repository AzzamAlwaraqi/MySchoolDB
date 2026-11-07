-- Housekeeping for MySchoolDB: trim the ever-growing Operation_Log/Data_Audit, defragment
-- indexes, refresh stats. Section 1 creates the proc; Section 2 schedules it via SQL Agent;
-- Section 3 is the Express fallback (no Agent there).
USE MYSchoolDB;
GO

-- SECTION 1 - the maintenance procedure
--   @RetentionDays  days of log history to keep (default 90)
--   @RebuildAtPct   fragmentation % at/above which an index is REBUILT, else REORGANIZED
--   @WhatIf         1 = report only, change nothing
IF EXISTS (SELECT 1 FROM sys.objects WHERE type='P' AND name='usp_Maintenance')
    DROP PROCEDURE usp_Maintenance;
GO
CREATE PROCEDURE usp_Maintenance
    @RetentionDays INT = 90,
    @RebuildAtPct  INT = 30,
    @WhatIf        BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cutoff DATETIME2 = DATEADD(DAY, -@RetentionDays, SYSDATETIME());
    DECLARE @opLogDeleted INT = 0, @auditDeleted INT = 0;
    DECLARE @sql NVARCHAR(MAX), @msg VARCHAR(200);

    BEGIN TRY
        -- 1) Trim the log tables back to the retention window
        IF @WhatIf = 0
        BEGIN
            DELETE FROM Operation_Log WHERE Log_DateTime  < @cutoff;
            SET @opLogDeleted = @@ROWCOUNT;

            DELETE FROM Data_Audit    WHERE Audit_DateTime < @cutoff;
            SET @auditDeleted = @@ROWCOUNT;
        END
        ELSE
        BEGIN
            SET @opLogDeleted = (SELECT COUNT(*) FROM Operation_Log WHERE Log_DateTime  < @cutoff);
            SET @auditDeleted = (SELECT COUNT(*) FROM Data_Audit    WHERE Audit_DateTime < @cutoff);
        END

        -- 2) Defragment indexes - reorganize light fragmentation, rebuild heavy.
        --    Skips tiny tables (under ~1000 pages fragmentation barely matters).
        DECLARE @schema SYSNAME, @table SYSNAME, @index SYSNAME, @frag FLOAT;
        DECLARE idx CURSOR LOCAL FAST_FORWARD FOR
            SELECT s.name, t.name, i.name, ps.avg_fragmentation_in_percent
            FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ps
            JOIN sys.indexes i ON i.object_id = ps.object_id AND i.index_id = ps.index_id
            JOIN sys.tables  t ON t.object_id = ps.object_id
            JOIN sys.schemas s ON s.schema_id = t.schema_id
            WHERE ps.avg_fragmentation_in_percent >= 10
              AND ps.page_count >= 1000
              AND i.name IS NOT NULL          -- skip heaps
              AND i.is_disabled = 0;

        OPEN idx;
        FETCH NEXT FROM idx INTO @schema, @table, @index, @frag;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @frag >= @RebuildAtPct
                SET @sql = N'ALTER INDEX ' + QUOTENAME(@index) + N' ON '
                         + QUOTENAME(@schema) + N'.' + QUOTENAME(@table) + N' REBUILD;';
            ELSE
                SET @sql = N'ALTER INDEX ' + QUOTENAME(@index) + N' ON '
                         + QUOTENAME(@schema) + N'.' + QUOTENAME(@table) + N' REORGANIZE;';

            IF @WhatIf = 0 EXEC sp_executesql @sql;
            FETCH NEXT FROM idx INTO @schema, @table, @index, @frag;
        END
        CLOSE idx;
        DEALLOCATE idx;

        -- 3) Refresh statistics so the planner has current numbers
        IF @WhatIf = 0 EXEC sp_updatestats;

        -- 4) Log what we did (into the log we just trimmed)
        SET @msg = CONCAT(
            CASE WHEN @WhatIf = 1 THEN 'Maintenance (WhatIf): ' ELSE 'Maintenance done: ' END,
            'Operation_Log -', @opLogDeleted, ' rows, Data_Audit -', @auditDeleted,
            ' rows older than ', @RetentionDays, ' days.');
        EXEC usp_WriteLog N'Maintenance', N'Housekeeping', NULL, 'SUCCESS', @msg, NULL;

        SELECT @msg AS Maintenance_Result;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','idx') >= 0 BEGIN CLOSE idx; DEALLOCATE idx; END
        DECLARE @err VARCHAR(200) = ERROR_MESSAGE();
        EXEC usp_WriteLog N'Maintenance', N'Housekeeping', NULL, 'FAILED', 'Maintenance failed.', @err;
        SELECT 'Maintenance failed.' AS Maintenance_Result, @err AS Error_Message;
    END CATCH
END
GO

-- Try it once in preview mode first - shows what it WOULD clean without changing anything:
--   EXEC usp_Maintenance @WhatIf = 1;
-- Then for real (keep 90 days of logs):
--   EXEC usp_Maintenance;


-- SECTION 2 - schedule it nightly with SQL Server Agent (Developer/Standard/Enterprise).
-- Runs usp_Maintenance every night at 02:00. Safe to re-run - drops the job first if present.
USE msdb;
GO
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'MySchoolDB - Nightly Maintenance')
    EXEC sp_delete_job @job_name = N'MySchoolDB - Nightly Maintenance';
GO

EXEC sp_add_job
     @job_name = N'MySchoolDB - Nightly Maintenance',
     @description = N'Trims Operation_Log/Data_Audit, defragments indexes, updates statistics.';

EXEC sp_add_jobstep
     @job_name   = N'MySchoolDB - Nightly Maintenance',
     @step_name  = N'Run usp_Maintenance',
     @subsystem  = N'TSQL',
     @database_name = N'MYSchoolDB',
     @command    = N'EXEC dbo.usp_Maintenance @RetentionDays = 90;';

EXEC sp_add_schedule
     @schedule_name = N'MySchoolDB - Every night 02:00',
     @freq_type     = 4,            -- daily
     @freq_interval = 1,            -- every 1 day
     @active_start_time = 020000;   -- 02:00:00

EXEC sp_attach_schedule
     @job_name      = N'MySchoolDB - Nightly Maintenance',
     @schedule_name = N'MySchoolDB - Every night 02:00';

EXEC sp_add_jobserver
     @job_name = N'MySchoolDB - Nightly Maintenance';   -- registers on the local server
GO

-- SECTION 3 - SQL Server Express fallback (no Agent): let Windows Task Scheduler run this
-- daily at 02:00. Save as RunMaintenance.bat, swap in your instance name:
--   sqlcmd -S .\SQLEXPRESS -d MYSchoolDB -Q "EXEC dbo.usp_Maintenance @RetentionDays = 90;" -b
