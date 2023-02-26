--Import data from phoenix.csv

DROP TABLE IF EXISTS #categories
CREATE TABLE #categories
(
	TopCategory varchar(150) NULL,
	SubCategory varchar(150) NULL
)

drop table if exists #phoenix
CREATE TABLE #phoenix (
[id] varchar(20) NOT NULL, 
[parent_id] varchar(20) NULL,
[brand] varchar(150) NULL, 
[brand_id] varchar(250) NULL,
[top_category] varchar(150) NULL,
[sub_category] varchar(150) NULL,
[category_tags] varchar(200) NULL,
[postal_code] varchar(8) NOT NULL,
[location_name] varchar(250) NOT NULL,
[latitude] float NOT NULL,
[longitude] float NOT NULL,
[country_code] varchar(4) NOT NULL,
[city] varchar(50) NOT NULL,
[region] varchar(4) NOT NULL,
[operation_hours] varchar(500) NULL,
[geometry_type] varchar(10) NOT NULL,
[polygon_wkt] varchar(max) NOT NULL
)

---------------------------------------
--1.Base import
--------------------------------------

BULK INSERT #phoenix
FROM 'C:\tmp\bups\phoenix.csv'
WITH
(
    FIRSTROW = 2, -- as 1st one is header
    FIELDTERMINATOR = ',',  --CSV field delimiter
    ROWTERMINATOR = '\n',   --Use to shift the control to next row
	FORMAT = 'csv',
	FIELDQUOTE = '"', 
    TABLOCK
)

alter table #phoenix
Add [parent_object_id] bigint null,
[brand_object_id] bigint null,
[category_id] bigint null,
[top_category_id] bigint null,
[city_id] bigint NULL

---------------------------------------
--2.Populate Brands
--------------------------------------

insert into dbo.Brands
(
	UniqueID, Name
)
select distinct P.[brand_id], P.[brand] 
from #phoenix P
where P.brand_id is not null
and not exists(select 1 from dbo.Brands B where B.UniqueId = P.[brand_id] and B.Name = P.[brand] )

update P
	set P.brand_object_id = B.ID
from #phoenix P
inner join dbo.Brands B
	on P.brand_id = B.UniqueID
where P.brand_object_id is null;

---------------------------------------
--3.Populate Cities
--------------------------------------

INSERT INTO dbo.Cities
(
	Name, Region, CountryCode
)
select distinct P.[city], P.[region], P.[country_code] from #phoenix P
where not exists(select 1 from dbo.Cities C where C.Name = P.city and C.Region = P.region and C.CountryCode = P.country_code)

update P
	set P.city_id = C.ID
from #phoenix P
inner join dbo.Cities C
	on P.country_code = C.CountryCode and
		P.city = C.Name and
		P.region = C.Region
where P.city_id is null

---------------------------------------
--4.Populate Categories
--------------------------------------

insert into #categories
( TopCategory, SubCategory )
select distinct	
	top_category, sub_category
from #phoenix

insert into #categories
( TopCategory, SubCategory )
select
	TopCategory, NULL
from 
(
	select distinct TopCategory from #categories where TopCategory is not null 
) C 
where not exists(select 1 from #categories CC where CC.TopCategory = C.TopCategory and CC.SubCategory is NULL)

delete from  #categories where TopCategory is null

insert into dbo.Categories
(
	Name
)
select 
	C.TopCategory
from #categories C
where C.SubCategory is null
and not exists(select 1 from dbo.Categories CC where CC.Name = C.TopCategory)

insert into dbo.Categories
(
	Name, ParentId
)
select
	C.SubCategory, CC.ID
from #categories C
inner join dbo.Categories CC
	on C.TopCategory = CC.Name
where C.SubCategory is not null
and not exists(select 1 from dbo.Categories CCC where CCC.Name = C.SubCategory and CCC.ParentId = CC.ID)

update P
set P.category_id = C.Id,
	P.top_category_id = C.Id
from #phoenix P
inner join dbo.Categories C 
	on P.top_category = C.Name
where P.top_category is not null
and P.sub_category is null

update P
set P.category_id = CC.Id,
	P.top_category_id = C.Id
from #phoenix P
inner join dbo.Categories C 
	on P.top_category = C.Name
inner join dbo.Categories CC
	on C.ID = CC.ParentId and P.sub_category = CC.Name
where P.top_category is not null
and P.sub_category is not null

---------------------------------------
--5.Populate Tags
--------------------------------------

INSERT INTO dbo.Tags
(
	TopCategoryID, Name
)
SELECT distinct
	 B.ParentCategoryID,
	 c.value as Tag
from (
select distinct 
	P.category_tags as Tags ,P.top_category_id as ParentCategoryID
from #phoenix P
where P.category_tags is not null) as B
cross apply string_split(B.Tags, ',') c
where not exists(select 1 from dbo.Tags T where T.Name = c.value and T.TopCategoryID = B.ParentCategoryID)

---------------------------------------
--6.Populate POIs
--------------------------------------

--First insert missing parent-pois as dummies
insert into dbo.PointsOfInterest 
(
	ID_Guid,
	BrandId,
	CategoryId,
	PostalCode,
	LocationName,
	Point,
	CityId,
	OperationHours,
	GeometryType,
	PolygonWkt
)
select
	UP.Id,
	NULL,
	NULL,
	'',
	'',
	geography::Point(CP.latitude,CP.longitude, 4326),
	CP.city_id,
	'',
	CP.geometry_type,
	case when ISNULL(CP.polygon_wkt,'') = '' 
			then geometry::STPolyFromText( 'POLYGON EMPTY', 4326)
		when CP.polygon_wkt like 'MULTI%'
			then geometry::Parse(CP.polygon_wkt)
		else 
			geometry::STPolyFromText(CP.polygon_wkt, 4326)
	end
from (
	select distinct 
		P.parent_id as id
	from #phoenix P
	where not exists(select 1 from #phoenix PP where PP.id = P.parent_id)
	and P.parent_id is not null
	and not exists(select 1 from dbo.PointsOfInterest POI where POI.ID_Guid = P.parent_id)
) UP
outer apply (
select top(1) 
	P.latitude, P.longitude,P.city_id,P.geometry_type,P.polygon_wkt
from #phoenix P
where P.parent_id = UP.id
) CP

insert into dbo.PointsOfInterest 
(
	ID_Guid,
	BrandId,
	CategoryId,
	PostalCode,
	LocationName,
	Point,
	CityId,
	OperationHours,
	GeometryType,
	PolygonWkt
)
select
	P.id,
	P.brand_object_id,
	P.category_id,
	P.postal_code,
	P.location_name,
	geography::Point(P.latitude,P.longitude, 4326),
	P.city_id,
	P.operation_hours,
	P.geometry_type,
	case when ISNULL(P.polygon_wkt,'') = '' 
			then geometry::STPolyFromText( 'POLYGON EMPTY', 4326)
		when P.polygon_wkt like 'MULTI%'
			then geometry::Parse(P.polygon_wkt)
		else 
			geometry::STPolyFromText(P.polygon_wkt, 4326)
	end
from #phoenix P
where not exists(select 1 from dbo.PointsOfInterest POI where POI.ID_Guid = P.id)


update P
	set P.[parent_object_id] = POI.Id
from #phoenix P
inner join dbo.PointsOfInterest POI
	on P.parent_id = POI.ID_Guid
where P.parent_id is not null

update POI
	set POI.ParentID = P.parent_object_id
from dbo.PointsOfInterest POI
inner join  #phoenix P
	on P.id = POI.ID_Guid
where P.parent_object_id is not null

---------------------------------------
--7.Populate POI-Tags
--------------------------------------
Insert into dbo.PointOfInterestTags
(PoiID, TagID)
select distinct
	POI.ID, T.ID
from #phoenix P
cross apply string_split(P.Category_tags, ',') c
inner join dbo.Tags T on c.value = T.Name and P.top_category_id = T.TopCategoryID
inner join dbo.PointsOfInterest POI
	on P.id = POI.ID_Guid
where not exists(select 1 from dbo.PointOfInterestTags POIT where POIT.PoiID = POI.ID and POIT.TagID = T.ID)

---------------------------------------
--8.Populate Config with default values
--------------------------------------
if not exists(select 1 from dbo.Config where Name = 'DefaultLongiutude')
begin
insert into dbo.Config
(Name, Value)
values
('DefaultLongiutude', '-112.07406594551456'),
('DefaultLatitude', '33.48838968274543'),
('DefaultRadius', '200');
end
GO
