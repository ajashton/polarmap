-- IMPORTANT: in order for this file to run you must first set an appropriate
-- 'epsg' variable. For example, in bash:
-- printf "\\set epsg 3995" | cat - make_grids.sql | psql

drop table if exists grid;

create table grid (
    geom geometry(linestring),
    class text,
    val integer,
    zmin integer,
    zmax integer
);
-- lines of latitude

insert into grid (
    select
        ST_Transform(ST_Segmentize(ST_SetSRID(ST_MakeLine(
            ST_MakePoint(-180, lat), ST_MakePoint(180, lat)),
            4326), 0.25), :epsg) as geom,
        'lat'::text as class,
        lat as val,
        case
            when lat % 20 = 0 then 0
            when lat % 10 = 0 then 2
            when lat %  5 = 0 then 3
            when lat %  2 = 0 then 4
            else 5 end as zmin,
        99 as zmax
    from (select generate_series(89, 0, -1) as lat) as sub
);

-- lines of longitude

create or replace function mklon (_lon float, _latmax float, _epsg integer)
    returns geometry
    language plpgsql immutable as
$func$
begin
    return ST_Transform(ST_SetSRID(ST_MakeLine(
            ST_MakePoint(_lon, _latmax),
            ST_MakePoint(_lon, 0)),
            4326),
        _epsg
    );
end;
$func$;

-- z1
insert into grid (
    select
        mklon(lon, 80, :epsg) as geom,
        'lon' as class,
        lon as val,
        0 as zmin,
        1 as zmax
    from (select generate_series(-180, 160, 20) as lon) as sub
);

-- z2
insert into grid (
    select
        case when lon % 20 = 0 then mklon(lon, 80, :epsg)
             else mklon(lon, 70, :epsg) end as geom,
        'lon' as class,
        lon as val,
        2 as zmin,
        2 as zmax
    from (select generate_series(-180, 170, 10) as lon) as sub
);

-- z3
insert into grid (
    select
        case when lon % 20 = 0 then mklon(lon, 85, :epsg)
             when lon % 10 = 0 then mklon(lon, 75, :epsg)
             else mklon(lon, 65, :epsg) end as geom,
        'lon' as class,
        lon as val,
        3 as zmin,
        3 as zmax
    from (select generate_series(-180, 175, 5) as lon) as sub
);

-- z4
insert into grid (
    select
        case when lon % 20 = 0 then mklon(lon, 88, :epsg)
             when lon % 10 = 0 then mklon(lon, 80, :epsg)
             else mklon(lon, 72, :epsg) end as geom,
        'lon' as class,
        lon as val,
        4 as zmin,
        4 as zmax
    from (select generate_series(-180, 178, 2) as lon) as sub
);

-- z5
insert into grid (
    select
        case when lon % 20 = 0 then mklon(lon, 89, :epsg)
             when lon % 10 = 0 then mklon(lon, 85, :epsg)
             when lon %  2 = 0 then mklon(lon, 80, :epsg)
             else mklon(lon, 75, :epsg) end as geom,
        'lon' as class,
        lon as val,
        5 as zmin,
        99 as zmax
    from (select generate_series(-180, 179, 1) as lon) as sub
);
