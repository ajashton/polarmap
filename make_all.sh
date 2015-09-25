#!/usr/bin/env bash
set -eu -o pipefail

source "$(dirname $0)/settings.sh"

pushd "$(pwd)"
mkdir -p "$DATADIR"
cd "$DATADIR"

if [ ! -e planet.osm.pbf ]; then
    wget -O planet.osm.pbf "$PBF_URL"
fi

if [ ! -e arctic_latest.osm.pbf ]; then
    osmconvert planet.osm.pbf -b="$BBOX" --complex-ways -o=arctic_latest.osm.pbf
fi

if [ $(($(date +%s)-$(stat -c '%Y' arctic_latest.osm.pbf))) -gt $((12*60*60)) ]
then
    # Updating the arctic extract to the latest OSM data with osmupdate.
    # This should take only a few minutes for each day's worth of changes.
    osmupdate arctic_latest.osm.pbf arctic_new.osm.pbf -b=$BBOX
    mv -f arctic_latest.osm.pbf arctic_old.osm.pbf
    mv -f arctic_new.osm.pbf arctic_latest.osm.pbf
fi

if [ ! -e arctic_land.shp ]; then
    wget -N http://data.openstreetmapdata.com/land-polygons-complete-4326.zip
    unzip -ju land-polygons-complete-4326.zip
    ogr2ogr -t_srs EPSG:$EPSG -clipsrc $BBOX_OGR \
        arctic_land.shp land_polygons.shp
fi

if [ ! -e natural_earth_vector.sqlite ]; then
    nezip=natural_earth_vector.sqlite.zip
    wget -O "$nezip" "http://naciscdn.org/naturalearth/packages/$nezip"
    unzip -ju $nezip -x CHANGELOG README.md VERSION
fi

if [ ! -e natural_earth_arctic.sqlite ]; then
    ogr2ogr \
        -clipsrc $BBOX_OGR \
        -f SQLite \
        natural_earth_arctic.sqlite \
        natural_earth_vector.sqlite \
            ne_10m_admin_0_boundary_lines_land \
            ne_10m_admin_0_boundary_lines_maritime_indicator \
            ne_10m_admin_0_countries \
            ne_10m_admin_1_states_provinces_lines_shp \
            ne_10m_admin_1_states_provinces_shp \
            ne_10m_airports \
            ne_10m_geographic_lines \
            ne_10m_geography_marine_polys \
            ne_10m_geography_regions_elevation_points \
            ne_10m_geography_regions_polys \
            ne_10m_glaciated_areas \
            ne_10m_land \
            ne_10m_land_ocean_label_points \
            ne_10m_ocean \
            ne_10m_parks_and_protected_lands_area \
            ne_10m_populated_places_simple \
            ne_10m_ports \
            ne_10m_roads \
            ne_10m_time_zones \
            ne_10m_urban_areas \
            ne_50m_land \
            ne_110m_land
fi

popd

## IMPORT

$PSQL -c "drop database $PG_DBNAME;" || true
$PSQL -c "create database $PG_DBNAME;"
$PSQLD -c "create extension if not exists postgis;"
$PSQLD -c "create extension if not exists hstore;"
$PSQLD -f ./pgsql/postgis-vt-util.sql
$PSQLD -f ./pgsql/functions.sql

# Generate Mask Layer
$PSQLD -c "create table mask as (select ST_Buffer(ST_Difference(
    ST_SetSRID(TileBBox(0, 0, 0), $EPSG),
    ST_Transform(ST_Segmentize(ST_MakeEnvelope($BBOX, 4326), 0.25), $EPSG)),
    -0.1) as geom);"

# Generate grids
printf "\\set epsg $EPSG\n" | cat - pgsql/make_grids.sql | $PSQLD


export PG_USE_COPY=TRUE
export OGR_ENABLE_PARTIAL_REPROJECTION=TRUE
export PGCLIENTENCODING=UTF8
ogr2ogr \
    -s_srs EPSG:4326 \
    -t_srs EPSG:$EPSG \
    -segmentize 0.25 \
    -f PostgreSQL \
    "PG:user=$PG_USER dbname=$PG_DBNAME host=$PG_HOST port=$PG_PORT" \
    "$DATADIR/natural_earth_arctic.sqlite" \
    -lco GEOMETRY_NAME=geom \
    -nlt GEOMETRY

export PGCLIENTENCODING=UTF8
osm2pgsql \
    --num-processes=$PROCS \
    --create \
    --proj=$EPSG \
    --database="$PG_DBNAME" \
    --username="$PG_USER" \
    --hstore \
    "$DATADIR/arctic_latest.osm.pbf"


## PROCESS

$PSQLD -f ./pgsql/pre_process.sql
parallel "set -eu -o pipefail; \
    printf '\\set procs $PROCS\n\\set proc {}\n' \
    | cat - ./pgsql/process.sql | $PSQLD" ::: $(seq 0 $((PROCS-1)))
