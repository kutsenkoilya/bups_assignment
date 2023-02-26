# billups_assignment

Assignment description can be found in Database Engineer_Coding Sample Instructions.pdf

Solution consists of following files:
- 00_DDL_CreateDB.sql - creates blank DB named poiData
- 01_DDL_CreateTables.sql - creates tables with indexes and constraints in poiData database
- 02_DDL_dbo.GetPointsOfInterest.sql and 02_DDL_tojson.sql - creates stored procedures and functions
- 03_DML_ImportData.sql - imports data from phoenix.csv into potData database tables
- 04_SPTestExec.sql - test samples of POI retreival SP
- poiData.7z - database full backup in 7zip archive

General overview:
- All dataset except work_hours column is normalized, because typically json-like strings are processed and validated on forntend
- Table constraints were added based on ideas that database is not a master-system for poi's and Tags are bound with Top categories
- Data import script is implemented in a way so multiple phoenix.csv files can be imported, but exising parent_id records will not be updated (can be done with merge or location_name='' check)
- GetPOI stored procedure has @DebugOutput param which shows parsed criteria and returned result as a table
- GetPOI stored procedure can be implemented with sp_executesql(sp, params[]) to remove unnesessary joins when criteria is empty, but this makes code less readable 
