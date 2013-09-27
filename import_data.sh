#!/bin/bash

EPSG=3395  # should be both a valid EPSG code and valid PostGIS SRID
BBOX="-180,60,180,90"  # latlon xmin,ymin,xmax,ymax
BBOX_OGR=$(sed 's/,/ /g' <<< $BBOX)  # like $BBOX, but no commas

get_planet() {
    wget -O planet.md5 http://planet.openstreetmap.org/pbf/planet-latest.osm.pbf.md5
    planet=$(sed 's/.* //' < planet.md5)
    test -e $latest || wget http://planet.openstreetmap.org/pbf/$planet
    md5sum -c planet.md5 || exit 1
}

cut_arctic() {
    # Extracting the arctic from the planet takes ~30min with osmconvert
    # and results in a ~600MB file.
    arctic=arctic$(sed 's/planet//' <<< "$planet")
    ~/src/osmconvert $planet -b=$BBOX --complex-ways $arctic
}

update_arctic() {
    local dst=arctic_updated.pbf
    if [ -e $dst ]; then
        mv -f $dst arctic_old.pbf
        local src=arctic_old.pbf
    else
        local src=$arctic
    fi
    # Updating the arctic should take only a few minutes for each days
    # worth of changes to apply
    osmupdate -b= $src $dst
}

gen_coastline() {
    wget -N http://data.openstreetmapdata.com/land-polygons-split-4326.zip
    unzip -f land-polygons-split-4326.zip
    ogr2ogr -t_srs EPSG:$EPSG -clipsrc $BBOX_OGR \
        arctic_land.shp land-polygons-split-4326/land_polygons.shp
    shapeindex arctic_land.shp
}

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
