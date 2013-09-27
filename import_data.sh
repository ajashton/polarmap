#!/bin/bash

DATADIR=$HOME/osmdata

EPSG=3395  # should be both a valid EPSG code and valid PostGIS SRID
BBOX="-180,60,180,90"  # latlon xmin,ymin,xmax,ymax
BBOX_OGR=$(sed 's/,/ /g' <<< $BBOX)  # like $BBOX, but no commas
MAX_COAST_AGE=$(bc <<< '24*60*60')

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
    ~/src/osmconvert $planet -b=$BBOX --complex-ways arctic_latest.osm.pbf
fi

# Updating the arctic extract to the latest OSM data with osmupdate.
# This should take only a few minutes for each day's worth of changes.
mv -f arctic_latest.osm.pbf arctic_old.osm.pbf
osmupdate -b=$BBOX arctic_old.osm.pbf arctic_latest.osm.pbf

# Download, reproject, and clip the latest coastline file, but only if our
# existing copy is older than $MAX_COASTLINE_AGE.
if [ ! -e land-polygons-split-4326.zip -o
        $(($(date +%s)-$(stat -c '%Y' "$coastzip"))) -gt $MAX_COAST_AGE ]
then
    wget -N http://data.openstreetmapdata.com/land-polygons-split-4326.zip
    unzip -f land-polygons-split-4326.zip
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

