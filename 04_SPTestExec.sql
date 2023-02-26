use [poiData]
GO
declare @JsonIn nvarchar(max)= '{
	"country":"US", 
	"region":"AZ",
	"city":"Phoenix",
	"name":"Big O Tires",
	"latitude":"33.4751",
	"longitude":"-112.221192",
	"radius":"1000",
	"polygonWKT":"POLYGON ((-112.22101954499999 33.47513648800003, -112.22105581099999 33.475005563000025, -112.22136468199994 33.47506401600003, -112.22132841699994 33.47519494200003, -112.22101954499999 33.47513648800003))"
	}',
	@JsonOut nvarchar(max) ;

exec dbo.GetPointsOfInterest
	@JsonIn = @JsonIn,
	@JsonOut  = @JsonOut out,
	@DebugOutput = 1

select @JsonOut
GO