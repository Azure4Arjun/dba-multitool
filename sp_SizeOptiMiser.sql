/* TO DO: 
* Get more specific about ideal time formats (#1) and make sure date and time dont create dups for same columns 
*/


--@GetGreedy 
IF OBJECT_ID(N'tempdb..#results') IS NOT NULL
DROP TABLE #results
GO

CREATE TABLE #results (
[ID] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
[check_num] INT NOT NULL,
[check_type] NVARCHAR(50) NOT NULL,
[obj_type] SYSNAME NOT NULL,
[obj_name] SYSNAME NOT NULL,
[col_name] SYSNAME NULL,
[message] NVARCHAR(250) NULL,
[ref_link] NVARCHAR(500) NULL);

DECLARE @isExpress BIT = 0;
DECLARE @getGreedy BIT = 0;

/* Find edition */
IF (CAST(SERVERPROPERTY('Edition') AS VARCHAR(50))) LIKE '%express%'
	SET @isExpress = 1;

INSERT INTO #results
SELECT '0', 'Let''s do this', 'Vroom, vroom', 'Off to the races!', 'Ready, set, go!', 'Last Updated 12/20/2017', 'http://expressdb.io';

/* Check 1: Did you mean to use a time based format? */
INSERT INTO #results
SELECT 1, N'Data Formats', 'USER_TABLE',  t.name, c.name, N'Column storing date should use a date or datetime format, but this column is using ' + ty.name + '.', N'https://goo.gl/uiltVb'
FROM sys.columns as c
	inner join sys.tables as t on t.object_id = c.object_id
	inner join sys.types as ty on ty.user_type_id = c.user_type_id
WHERE c.is_identity = 0 --exclude identity cols
	AND t.is_ms_shipped = 0 --exclude sys table
	AND c.name LIKE '%date%' 
	AND ty.name NOT IN ('datetime', 'datetime2', 'datetimeoffset', 'date', 'smalldatetime')
	
INSERT INTO #results 
SELECT 1, N'Data Formats', 'USER_TABLE', t.name, c.name, N'Column storing time should use a time, datetime, or sometimes integer format, but this column is using ' + ty.name + '.', N'https://goo.gl/uiltVb'
FROM sys.columns as c
	inner join sys.tables as t on t.object_id = c.object_id
	inner join sys.types as ty on ty.user_type_id = c.user_type_id
WHERE c.is_identity = 0 --exclude identity cols
	AND t.is_ms_shipped = 0 --exclude sys table
	AND c.name LIKE '%time%'
	AND ty.name NOT IN ('datetime', 'datetime2', 'datetimeoffset', 'date', 'time', 'int')
	
/* Check 2: Old School Variable Lengths (255/256) */
INSERT INTO #results 
SELECT 2, N'Data Formats', 'USER_TABLE', t.name, c.name, N'Possible arbitrary variable length column in use. Is the ' + ty.name + ' length of ' + CAST (c.max_length / 2 AS varchar(10)) + ' based on real requirements?', N'https://goo.gl/uiltVb'
FROM sys.columns as c
	inner join sys.tables as t on t.object_id = c.object_id
	inner join sys.types as ty on ty.user_type_id = c.user_type_id
WHERE c.is_identity = 0 --exclude identity cols
	AND t.is_ms_shipped = 0 --exclude sys table
	AND ty.name = 'nvarchar'
	AND c.max_length IN (510, 512)
UNION
SELECT 2, N'Data Formats', 'USER_TABLE', t.name, c.name, N'Possible arbitrary variable length column in use. Is the ' + ty.name + ' length of ' + CAST (c.max_length AS varchar(10)) + ' based on real requirements?', N'https://goo.gl/uiltVb'
FROM sys.columns as c
	inner join sys.tables as t on t.object_id = c.object_id
	inner join sys.types as ty on ty.user_type_id = c.user_type_id
WHERE c.is_identity = 0 --exclude identity cols
	AND t.is_ms_shipped = 0 --exclude sys table
	AND ty.name = 'varchar'
	AND c.max_length IN (255, 256)
	
/* Check 3: Mad MAX - Varchar(MAX) */

/* Check 4: User DB or model db  Growth set past 10GB */

/* Check 5: User DB or model db growth set to % */

/* Check 6: Do you really need Nvarchar - possible scan of data? */
IF (@getGreedy AND @isExpress)
	BEGIN
	
	END

/* Check 7: BIGINT for identity values - sure its needed ?  - ONLY IF EXPRESS*/
IF (@isExpress)
	BEGIN
		SELECT 7, N'Data Formats', 'USER_TABLE', t.name, c.name, N'BIGINT used on IDENTITY column in SQL Express. If values will never exceed 2,147,483,647 use INT instead.', N'https://goo.gl/uiltVb'
		FROM sys.columns as c
			inner join sys.tables as t on t.object_id = c.object_id
			inner join sys.types as ty on ty.user_type_id = c.user_type_id
		WHERE t.is_ms_shipped = 0 --exclude sys table
			AND ty.name = 'BIGINT'
			AND c.is_identity = 1 
	END

/* Check 8: Don't use FLOAT or REAL */
INSERT INTO #results
select 8, 'Data Formats', o.type_desc, o.name, ac.name, N'Are you sure you want to use ' + st.name + ' and not DECIMAL/NUMERIC?', N'https://goo.gl/uiltVb'
from sys.all_columns as ac
    inner join sys.objects as o on o.object_id = ac.object_id
    inner join sys.systypes as st on st.xtype = ac.system_type_id
where st.name IN ('float', 'real')
    and o.type_desc = 'USER_TABLE'

/* Check 9: Don't use deprecated values (NTEXT, TEXT, IMAGE) */
INSERT INTO #results
select 9, 'Data Formats', o.type_desc, o.name, ac.name, N'Deprecated data type in use: ' + st.name + '.', N'https://goo.gl/u9SgEj'
from sys.all_columns as ac
    inner join sys.objects as o on o.object_id = ac.object_id
    inner join sys.systypes as st on st.xtype = ac.system_type_id
where st.name IN ('next', 'text', 'image')
    and o.type_desc = 'USER_TABLE'

/* Check 10: Non-default fill factor */
/* Check 11: More than 5 indexes */

/* Check 12: Should sparse columns be used? */
/* Check 13: Compression (2016 SP1+ only for express) */

/* CHeck 14: numeric or decimal without trailing 0s */
INSERT INTO #results
SELECT 14, 'Data Formats', o.type_desc, o.name, ac.name, N'Column is ' + UPPER(st.name) + '(' + CAST(ac.precision AS VARCHAR) + ',' + CAST(ac.scale AS VARCHAR) + ')' + '. Consider using an INT variety for space reduction.', N'https://goo.gl/agh5CA'
FROM sys.objects as o
    inner join sys.all_columns as ac ON ac.object_id = o.object_id
    INNER JOIN sys.systypes as st on st.xtype = ac.system_type_id
WHERE ac.scale = 0
    AND st.name IN ('decimal', 'numeric')

	

select * from #results;
