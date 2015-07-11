#!/usr/bin/env bash
set -eu -o pipefail

SRCDIR=$HOME/src

apt_packages=(
    build-essential
    libbz2-dev          # for building osm2pgsql
    libgeos++-dev       # for building osm2pgsql
    libmapnik
    libmapnik-dev
    libprotobuf-dev     # for building osm2pgsql, osmium
    postgresql-9.3-postgis-2.1
    zlib1g-dev          # for building osmconvert
)

install_packages() {
    sudo apt-get update
    sudo apt-get install -y ${apt_packages[@]}
}


build_osmconvert() {
    wget -O - http://m.m.i24.cc/osmconvert.c | cc -x c - -lz -O3 -o osmconvert
    sudo cp osmconvert /usr/local/bin/
}

build_osmupdate() {
    wget -O - http://m.m.i24.cc/osmupdate.c | cc -x c - -o osmupdate
    sudo cp osmupdate /usr/local/bin/
}

# Do it
install_packages
mkdir -p $SRCDIR
cd $SRCDIR
build_osmconvert
build_osmupdate
