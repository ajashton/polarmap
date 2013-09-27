# OpenPolarMap

## Overview

- OSM data, updated regularly
- Polar projection (just start with Arctic?)

## Process

Ubuntu cloud server. Linode?

- ubuntu-setup.sh
    - installs packages from repos where sensible
    - compiles recent versions of other software where necessary
        - osmconvert? <http://wiki.openstreetmap.org/wiki/Osmconvert>
        - osmium?
    - sets up PostgreSQL accordingly
- import-data.sh
    - downloads latest planet file if there is a new one & cuts out just the arctic
    - updates the arctic extract
    - imports the arctic extract using osm2pgsql

## Import

Imposm3? osm2pgsql? osmium?

## Style

CartoCSS

## Serving tiles

Very much TBD. Tirex? Vector tiles?

