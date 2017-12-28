﻿-- https://docs.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/overview-and-usage-scenarios
USE master;
GO

DECLARE @databaseFilePath NVARCHAR(1000) = N'k:\MSSQL\MSSQL14.MSSQLSERVER\MSSQL\DATA\'--N'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\';
DECLARE @databaseName     SYSNAME        = N'ಠ ಠ 14 Test';
DECLARE @tsqlStatement    NVARCHAR(4000) = N'';
DECLARE @debug            BIT            = 0;

SET @tsqlStatement = '
IF DB_ID(N''@databaseName'') IS NOT NULL
BEGIN
    ALTER DATABASE [@databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE  [@databaseName];
END;

CREATE DATABASE [@databaseName]
 CONTAINMENT = NONE
 ON  PRIMARY
(NAME = N''@databaseName'', FILENAME = N''@databaseFilePath@databaseName.mdf'', SIZE = 64MB, MAXSIZE = UNLIMITED, FILEGROWTH = 64MB),
FILEGROUP [___DATABASE_NAME___] CONTAINS MEMORY_OPTIMIZED_DATA DEFAULT
( NAME = N''@databaseName_mod'', FILENAME = N''@databaseFilePath@databaseName_mod'', MAXSIZE = UNLIMITED)
 LOG ON 
( NAME = N''@databaseName_log'', FILENAME = N''@databaseFilePath@databaseName_log.ldf'', SIZE = 64MB, MAXSIZE = 2048MB, FILEGROWTH = 64MB);

ALTER DATABASE [@databaseName] SET COMPATIBILITY_LEVEL = 120;

USE [@databaseName];

-- configure recommended DB option
ALTER DATABASE CURRENT SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT=ON;

-- memory-optimized table
CREATE TABLE dbo.table1(
    c1 INT IDENTITY PRIMARY KEY NONCLUSTERED,
    c2 NVARCHAR(4000)
)
WITH (MEMORY_OPTIMIZED=ON);

-- non-durable table
CREATE TABLE dbo.temp_table1
( c1 INT IDENTITY PRIMARY KEY NONCLUSTERED,
  c2 NVARCHAR(4000))
WITH (MEMORY_OPTIMIZED=ON,
      DURABILITY=SCHEMA_ONLY);

 -- memory-optimized table type
CREATE TYPE dbo.tt_table1 AS TABLE
( c1 INT IDENTITY,
   c2 NVARCHAR(4000),
   is_transient BIT NOT NULL DEFAULT (0),
   INDEX ix_c1 HASH (c1) WITH (BUCKET_COUNT=1024))
 WITH (MEMORY_OPTIMIZED=ON);

CREATE TABLE dbo.InMemTable1
(
keyColumn INT IDENTITY PRIMARY KEY NONCLUSTERED
,description CHAR(100) NOT NULL
)
WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);

INSERT dbo.InMemTable1(description)
VALUES
 (REPLICATE(''A'', 100))
,(REPLICATE(''B'', 100))
,(REPLICATE(''C'', 100))
,(REPLICATE(''D'', 100))
,(REPLICATE(''E'', 100))
,(REPLICATE(''F'', 100));
';

SET @tsqlStatement = REPLACE(@tsqlStatement, '@databaseName',     @databaseName);
SET @tsqlStatement = REPLACE(@tsqlStatement, '@databaseFilePath', @databaseFilePath);

IF @debug = 1 PRINT(@tsqlStatement)
ELSE
EXEC sp_executesql @tsqlStatement;


--https://stackoverflow.com/a/793362/2298061
DECLARE @UseAndExecStatment NVARCHAR(4000);
SET @UseAndExecStatment = N'USE [' + @databaseName + N']; EXEC sp_executesql @tsqlStatement';

SET @tsqlStatement = N'
CREATE PROCEDURE dbo.native_sp
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N''us_english'')
    SELECT keyColumn
         , description
    FROM dbo.InMemTable1;
END;
--EXECUTE dbo.native_sp;';

EXEC sp_executesql @UseAndExecStatment,
     N'@tsqlStatement NVARCHAR(MAX)', @tsqlStatement = @tsqlStatement
