--SP to retreive points by criteria
----Input param:
--1. Country;2. Region;3. City;4. Exact location with given radius;5. User defined area passed as WKT Polygon;6. POI category;7. POI name
----Output param:
--1. Id;2. Parent ID (if exists);3. Country code;4. Region Code;5. City Name;6. Location coordinates (latitude, longitude);7. Category
--8. Sub category (if exists);9. WKT Polygon (if exists);10. Location Name;11. Postal code;12. Operation Hours (if exists)
----@DebugOutput - show parsed criteria values and result dataset as a table
---Input json example:
--'{
--"country":"US", 
--"region":"AZ",
--"city":"Phoenix",
--"name":"Big O Tires",
--"latitude":"33.4751",
--"longitude":"-112.221192",
--"radius":"1000",
--"polygonWKT":"POLYGON ((-112.22101954499999 33.47513648800003, -112.22105581099999 33.475005563000025, -112.22136468199994 33.47506401600003, -112.22132841699994 33.47519494200003, -112.22101954499999 33.47513648800003))"
--}'
---Output json example:
--{
--"data":[{
--"id":"223-222@8ts-d6j-dgk",
--"country_code":"US",
--"region_code":"AZ",
--"city_name":"Phoenix",
--"point":{"type": "Point","coordinates":[-112.221192,33.4751]},
--"category":"Automotive Parts, Accessories, and Tire Stores",
--"sub_category":"Automotive Parts and Accessories Stores",
--"polygon":{"type": "Polygon","coordinates":[[[...]]]}]}
------------------------------------
DROP PROCEDURE IF EXISTS dbo.GetPointsOfInterest;
GO
CREATE PROCEDURE dbo.GetPointsOfInterest 
(
	@JsonIn nvarchar(max),
	@JsonOut nvarchar(max) out,
	@DebugOutput int = 0
)
AS
BEGIN
	declare @Country varchar(4),
		@Region varchar(100),
		@City varchar(50),
		
		@Category varchar(250),

		@Name varchar(250),

		@Latitude float, 
		@Longitude float,
		@Point geography,
		@Radius float = 200,
		
		@PolygonWKTStr nvarchar(max),
		@PolygonWKT geometry;

	if (isnull(@JsonIn,'') = '' or @JsonIn = '{}')
	begin
		select top(1) @Latitude = cast(C.Value as float)
		from dbo.Config C
		where C.Name = 'DefaultLatitude'
		order by C.ID desc

		select top(1) @Longitude = cast(C.Value as float)
		from dbo.Config C
		where C.Name = 'DefaultLongiutude'
		order by C.ID desc

		select top(1) @Radius = cast(C.Value as float)
		from dbo.Config C
		where C.Name = 'DefaultRadius'
		order by C.ID desc

		set @Point = geography::Point(@Latitude,@Longitude, 4326);
	end
	ELSE
	BEGIN
		select top(1)
			@Country = NULLIF(JS.country,''),
			@Region = NULLIF(JS.region,''),
			@City = NULLIF(JS.city,''),
			@Name = NULLIF(JS.name,''),
			@Category = NULLIF(JS.Category,''),
			@Latitude = try_cast(JS.latitude as float),
			@Longitude = try_cast(JS.longitude as float),
			@Radius = try_cast(JS.radius as float),
			@PolygonWKTStr = NULLIF(JS.polygonWKT,'')
		from	openjson(@JsonIn)
		with	(country	varchar(8)		'$.country',
				 region		varchar(8)		'$.region',
				 city       varchar(100)    '$.city',
				 name		nvarchar(150)	'$.name',
				 category	nvarchar(250)	'$.category',
				 latitude	nvarchar(50)	'$.latitude',
				 longitude	nvarchar(50)	'$.longitude',
				 radius		nvarchar(50)	'$.radius',
				 polygonWKT	nvarchar(max)	'$.polygonWKT') as JS
		
		if (isnull(@PolygonWKTStr,'') <> '')
		begin
			set @PolygonWKT = geometry::STGeomFromText(@PolygonWKTStr, 4326)
		end

		if @Latitude is not null and @Longitude is not null
		begin
			set @Point = geography::Point(@Latitude, @Longitude, 4326);
		end

		if (@Radius <= 0)
		begin
			select top(1) @Radius = cast(C.Value as float)
			from dbo.Config C
			where C.Name = 'DefaultRadius'
			order by C.ID desc
		end
	END

	IF (@DebugOutput = 1)
	begin
		select @Country,
				@Region,
				@City,
				@Name,
				@Category,
				@Latitude,
				@Longitude,
				@Radius,
				@PolygonWKTStr
	end

	drop table if exists #tmpCities
	create table #tmpCities
	(
		ID bigint not null primary key,
		City varchar(50) not null,
		Region varchar(100) not null,
		Country varchar(4) not null
	)

	insert into #tmpCities(ID, City, Region, Country)
	select C.ID, C.Name, C.Region, C.CountryCode
	from dbo.Cities C
	where (C.Name = @City or @City is null)
		AND (C.CountryCode = @Country or @Country is null)
		AND (C.Region = @Region or @Region is null)

	if @@ROWCOUNT = 0
	begin
		select @JsonOut = '{"error": "No cities found. Please refine input criteria."}';	
		return;
	end

	drop table if exists #tmpCategories
	create table #tmpCategories
	(
		ID bigint not null primary key,
		ParentName varchar(150) null,
		Name varchar(150) null
	)

	insert into #tmpCategories
	(ID, ParentName, Name)
	select 
		ID, Name, NULL
	from dbo.Categories C
	where (C.Name = @Category or @Category is null)
	and C.ParentId is null
	UNION
	select 
		C.ID, PC.Name, C.Name
	from dbo.Categories C --Children
	inner join dbo.Categories PC --Parent
		on C.ParentId = PC.ID
	where (PC.Name = @Category or @Category is null)

	if @@ROWCOUNT = 0
	begin
		select @JsonOut = '{"error": "No Categories found. Please refine input criteria."}';	
		return;
	end

	IF (@DebugOutput = 1)
	begin
		select 
			POI.ID_Guid as 'id',
			PPOI.ID_Guid as 'parent_id',
			C.Country as 'country_code',
			C.Region as 'region_code', 
			C.City as 'city_name',
			dbo.geography2json(POI.Point) as 'point',
			CA.ParentName as 'category',
			CA.Name as 'sub_category',
			dbo.geometry2json(POI.PolygonWkt) as 'polygon',
			POI.LocationName as 'location_name',
			POI.PostalCode as 'postal_code',
			POI.OperationHours as 'operation_hours'
		from dbo.PointsOfInterest POI
		left join dbo.PointsOfInterest PPOI 
			on POI.ParentId = PPOI.ID
		inner join #tmpCities C
			on C.ID = POI.CityId
		inner join #tmpCategories CA
			on CA.ID = POI.CategoryId
		where (POI.LocationName = @Name or @Name is null)
			and (@Point.STDistance(POI.Point) <= @Radius or @Point is null)
			and (@PolygonWKT.STIntersects(POI.PolygonWKT) = 1 or @PolygonWKT is null)
	end

	set @JsonOut = ISNULL((
		select 
			POI.ID_Guid as 'id',
			PPOI.ID_Guid as 'parent_id',
			C.Country as 'country_code',
			C.Region as 'region_code', 
			C.City as 'city_name',
			JSON_QUERY(dbo.geography2json(POI.Point)) as 'point',
			CA.ParentName as 'category',
			CA.Name as 'sub_category',
			JSON_QUERY(dbo.geometry2json(POI.PolygonWkt)) as 'polygon',
			POI.LocationName as 'location_name',
			POI.PostalCode as 'postal_code',
			JSON_QUERY(POI.OperationHours) as 'operation_hours'
		from dbo.PointsOfInterest POI
		left join dbo.PointsOfInterest PPOI 
			on POI.ParentId = PPOI.ID
		inner join #tmpCities C
			on C.ID = POI.CityId
		inner join #tmpCategories CA
			on CA.ID = POI.CategoryId
		where (POI.LocationName = @Name or @Name is null)
			and (@Point.STDistance(POI.Point) <= @Radius or @Point is null)
			and (@PolygonWKT.STIntersects(POI.PolygonWKT) = 1 or @PolygonWKT is null)
		FOR JSON PATH, ROOT('data')
	),'{"data":[]}');
END
GO

