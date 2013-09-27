SRCDIR=$HOME/src

distrib_supported=(raring)

apt_sources=(
    ppa:mapnik/nightly-trunk
    ppa:duh/golang
)

apt_packages=(
    build-essential
    libbz2-dev          # for building osm2pgsql
    libgeos++-dev       # for building osm2pgsql
    libmapnik
    libmapnik-dev
    libprotobuf-dev     # for building osm2pgsql, osmium
    postgresql
    #postgresql-contrib
    postgresql-server-dev-9.1
    zlib1g-dev          # for building osmconvert
)

install_packages() {
    echo "Setting up apt sources..."
    for source in "${apt_sources[@]}"; do
        sudo apt-add-repository "$source"
    done
    sudo apt-get update
    sudo apt-get install ${apt_packages[@]}
}


build_osmconvert() {
    wget -O - http://m.m.i24.cc/osmconvert.c | cc -x c - -lz -O3 -o osmconvert
    sudo cp osmconvert /usr/local/bin/
}

build_osmupdate() {
    wget -O - http://m.m.i24.cc/osmupdate.c | cc -x c - -o osmupdate
    sudo cp osmupdate /usr/local/bin/
}

build_postgis() {
    local v=2.0.3
    wget -O - http://download.osgeo.org/postgis/source/postgis-$v.tar.gz \
        | tar xz
    cd postgis-$v
    ./configure
    make
    sudo make install
}

# Do it
install_packages
mkdir -p $SRCDIR
cd $SRCDIR
build_osmconvert
build_osmupdate
build_postgis
