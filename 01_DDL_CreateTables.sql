use [poiData]

--Categories in hierarchical order
DROP TABLE IF EXISTS dbo.Categories
CREATE TABLE dbo.Categories
(
	ID bigint identity(1,1) NOT NULL primary key,
	Name varchar(150) NOT NULL,
	ParentId bigint NULL,
	CONSTRAINT UX_Categories_ParentID_Name UNIQUE (ParentId, Name)
)

--Tags with top_categories
DROP TABLE IF EXISTS dbo.Tags
CREATE TABLE dbo.Tags
(
	ID bigint identity(1,1) NOT NULL primary key,
	TopCategoryID bigint NOT NULL,
	Name varchar(150) NULL,
	CONSTRAINT UX_Tags_TopCategoryID_Name UNIQUE (TopCategoryID, Name)
)

--Point - Tag relation
DROP TABLE IF EXISTS dbo.PointOfInterestTags
CREATE TABLE  dbo.PointOfInterestTags
(
	PoiID bigint not null,
	TagID bigint not null,
	primary key (PoiID, TagID) ,
	INDEX IX_PointOfInterestTags_PoiId nonclustered (PoiID),
	INDEX IX_PointOfInterestTags_TagID nonclustered (TagID)
)

--Cities
DROP TABLE IF EXISTS dbo.Cities
CREATE TABLE dbo.Cities
(
	ID bigint identity(1,1) NOT NULL primary key,
	Name nvarchar(50) NOT NULL,
	Region varchar(4) NOT NULL,
	CountryCode varchar(4) NOT NULL
	CONSTRAINT UX_Cities_Name_Region_CountryCode UNIQUE (Name,Region,CountryCode)
)

--Brands
DROP TABLE IF EXISTS dbo.Brands
CREATE TABLE dbo.Brands
(
	ID bigint identity(1,1) NOT NULL primary key,
	UniqueID varchar(250) NOT NULL,
	Name nvarchar(150) NOT NULL,
	CONSTRAINT UX_Brands_UniqueID UNIQUE (UniqueID)
)

--Points of interest
DROP TABLE IF EXISTS dbo.PointsOfInterest 
CREATE TABLE dbo.PointsOfInterest 
(
	ID bigint identity(1,1) NOT NULL primary key, -- Object_id
	ID_Guid varchar(20) NOT NULL, --id
	ParentId bigint NULL, --object_parent_id
	BrandId bigint NULL, --brand_object_id
	CategoryId bigint NULL, --category_id
	PostalCode varchar(8) NOT NULL, --postal_code
	LocationName varchar(250) NOT NULL, --location_name
	Point geography not null,
	CityId bigint NOT NULL, --city_id
	OperationHours varchar(500) NULL, --operation_hours
	GeometryType varchar(10) NOT NULL, --geometry_type
	PolygonWkt geometry NOT NULL, --polygon_wkt
	CONSTRAINT UX_PointsOfInterest_ID_Guid UNIQUE (ID_Guid),
	INDEX IX_PointOfInterestTags_CategoryId nonclustered (CategoryId),
	INDEX IX_PointOfInterestTags_CityId nonclustered (CityId),
)

create spatial index [SPIX_PointsOfInterest_Point] on [PointsOfInterest] ([Point]);

--Can be added but I didn't found out how to properly set BOUNDING_BOX
--create spatial index [SPIX_PointsOfInterest_PolygonWkt] on [PointsOfInterest] ([PolygonWkt])


--Configuration key-value table for default-values storage
DROP TABLE IF EXISTS dbo.Config
CREATE TABLE dbo.Config
(
	ID int identity(1,1) not null primary key,
	Name varchar(250) not null unique,
	Value varchar(250) not null,
	INDEX IX_Config_Name unique nonclustered (Name)
)

GO

