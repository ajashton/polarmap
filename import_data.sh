#!/usr/bin/env bash
set -eu -o pipefail

PBF_URL="${PBF_URL:-http://planet.openstreetmap.org/pbf/planet-latest.osm.pbf}"
DATADIR=./data
EPSG=3995   # should be both a valid EPSG code and valid PostGIS SRID
BBOX="-180,45,180,90"           # latlon xmin,ymin,xmax,ymax
BBOX_OGR=${BBOX//,/ }           # like $BBOX, but no commas
PG_DBNAME=${PG_DBNAME:-openpolarmap}
PG_USER=${PG_USER:-postgres}
PG_HOST=${PG_HOST:-localhost}
PG_PORT=${PG_PORT:-5432}
PSQL="psql -U $PG_USER -h $PG_HOST -p $PG_PORT"
PSQLD="$PSQL -d $PG_DBNAME"

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

if [ ! -e arctic_land.shp -o \
    $(($(date +%s)-$(stat -c '%Y' arctic_land.shp))) -gt $((48*60*60)) ]
then
    wget -N http://data.openstreetmapdata.com/land-polygons-complete-4326.zip
    unzip -ju land-polygons-complete-4326.zip
    ogr2ogr -t_srs EPSG:$EPSG -clipsrc $BBOX_OGR \
        arctic_land.shp land-polygons-split-4326/land_polygons.shp
fi

if [ ! -e natural_earth_vector.sqlite ]; then
    nezip=natural_earth_vector.sqlite.zip
    wget -O "$nezip" "http://naciscdn.org/naturalearth/packages/$nezip"
    unzip -ju $nezip natural_earth_vector.sqlite
fi

if [ ! -e natural_earth_arctic.sqlite ]; then
    ogr2ogr \
        -clipsrc $BBOX_OGR \
        -f SQLite \
        natural_earth_arctic.sqlite \
        natural_earth_vector.sqlite \
            ne_10m_geographic_lines \
            ne_10m_geography_marine_polys \
            ne_10m_geography_regions_polys \
            ne_10m_glaciated_areas \
            ne_10m_land \
            ne_10m_ocean \
            ne_10m_populated_places_simple \
            ne_10m_ports \
            ne_10m_time_zones \
            ne_10m_urban_areas
fi

## IMPORT

$PSQL -c "drop database $PG_DBNAME;" || true
$PSQL -c "create database $PG_DBNAME;"
$PSQLD -c "create extension if not exists postgis;"
$PSQLD -c "create extension if not exists hstore;"

export PG_USE_COPY=TRUE
export OGR_ENABLE_PARTIAL_REPROJECTION=TRUE
export PGCLIENTENCODING=LATIN1
ogr2ogr \
    -s_srs EPSG:4326 \
    -t_srs EPSG:$EPSG \
    -segmentize 0.25 \
    -f PostgreSQL \
    "PG:user=$PG_USER dbname=$PG_DBNAME host=$PG_HOST port=$PG_PORT" \
    natural_earth_arctic.sqlite \
    -lco GEOMETRY_NAME=geom \
    -nlt GEOMETRY

export PGCLIENTENCODING=UTF8
osm2pgsql \
    --create \
    --proj=$EPSG \
    --database="$PG_DBNAME" \
    --username="$PG_USER" \
    --hstore \
    arctic_latest.osm.pbf
