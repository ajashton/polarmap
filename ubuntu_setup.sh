#!/usr/bin/env bash
set -eu -o pipefail

SRCDIR=${TEMP:-/tmp}/src

apt_packages=(
    postgresql-9.3-postgis-2.1
    # for building osm2pgsql:
    autoconf
    automake
    libtool
    make
    g++
    pkg-config
    libboost-dev
    libboost-system-dev
    libboost-filesystem-dev
    libboost-thread-dev
    libexpat1-dev
    libgeos-dev
    libgeos++-dev
    libpq-dev
    libbz2-dev
    libproj-dev
    zlib1g-dev  # also needed to build osmconvert
    protobuf-compiler
    libprotobuf-dev
    lua5.2
    liblua5.2-dev
)

install_packages() {
    sudo apt-get update
    sudo apt-get install -y "${apt_packages[@]}"
}

install_node() {
    wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.25.4/install.sh | bash
    git clone https://github.com/creationix/nvm.git ~/.nvm
    pushd ~/.nvm
    git checkout "$(git describe --abbrev=0 --tags)"
    popd
    source ~/.nvm/nvm.sh
    nvm install v0.10
    nvm use v0.10
}

build_osmconvert() {
    wget -O - http://m.m.i24.cc/osmconvert.c | cc -x c - -lz -O3 -o osmconvert
    sudo mv osmconvert /usr/local/bin/
}

build_osmupdate() {
    wget -O - http://m.m.i24.cc/osmupdate.c | cc -x c - -o osmupdate
    sudo mv osmupdate /usr/local/bin/
}

build_osm2pgsql() {
    pushd "$(pwd)"
    git clone https://github.com/openstreetmap/osm2pgsql.git osm2pgsql
    cd osm2pgsql
    ./autogen.sh
    ./configure
    make -j8
    sudo make install
    popd
}

# Do it
install_packages
mkdir -p "$SRCDIR"
cd "$SRCDIR"

if [ -z "$(which node)" ]; then
    install_node
fi

if [ -z "$(which osmconvert)" ]; then
    build_osmconvert
fi

if [ -z "$(which osmupdate)" ]; then
    build_osmupdate
fi

if [ -z "$(which osm2pgsql)" ]; then
    build_osm2pgsql
fi

