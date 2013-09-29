#!/bin/bash

# This script loads a database with an up-to-date extract of OSM data for
# the arctic. If an arctic extract file is not locally available, it will
# download the latest weekly OSM Planet dump and create one.
#
# This file will also fetch and process any additional required data such as
# coastline shapefiles. If these already exist locally but are out of date,
# they will be updated.

DATADIR=$HOME/osmdata

EPSG=3395   # should be both a valid EPSG code and valid PostGIS SRID
BBOX="-180,60,180,90"                   # latlon xmin,ymin,xmax,ymax
BBOX_OGR=$(sed 's/,/ /g' <<< $BBOX)     # like $BBOX, but no commas
MAX_COAST_AGE=$(bc <<< '24*60*60')      # in seconds

mkdir -p $DATADIR
cd $DATADIR

# If we don't yet have an arctic extract to work with, download the latest
# planet and create one with osmcovert.
if [ ! -e arctic_latest.osm.pbf ]; then
    wget -O planet.md5 http://planet.openstreetmap.org/pbf/planet-latest.osm.pbf.md5
    planet=$(sed 's/.* //' < planet.md5)
    test -e $planet || wget http://planet.openstreetmap.org/pbf/$planet
    md5sum -c planet.md5 || exit 1
    # Extracting the arctic from the planet takes ~30min with osmconvert
    # and results in a ~600MB file.
    echo -n "Creating arctic extract... "
    osmconvert $planet -b=$BBOX --complex-ways -o=arctic_latest.osm.pbf
    echo "done."
fi

# Updating the arctic extract to the latest OSM data with osmupdate.
# This should take only a few minutes for each day's worth of changes.
mv -f arctic_latest.osm.pbf arctic_old.osm.pbf
echo -n "Updating OSM data... "
osmupdate arctic_old.osm.pbf arctic_latest.osm.pbf -b=$BBOX
echo "done."

# Download, reproject, and clip the latest coastline file, but only if our
# existing copy is older than $MAX_COASTLINE_AGE.
coastzip=land-polygons-split-4326.zip
if [ ! -e $coastzip -o \
    $(($(date +%s)-$(stat -c '%Y' "$coastzip"))) -gt $MAX_COAST_AGE ]
then
    wget -N http://data.openstreetmapdata.com/$coastzip
    unzip -f $coastzip
    ogr2ogr -t_srs EPSG:$EPSG -clipsrc $BBOX_OGR \
        arctic_land.shp land-polygons-split-4326/land_polygons.shp
fi

import_arctic() {
    osm2pgsql \
        --create \
        --prefix=osm_arctic \
        --proj=$EPSG \
        --database=osm \
        --username=postgres \
        --hstore \
        $planet
}

