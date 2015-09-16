PBF_URL="${PBF_URL:-http://planet.openstreetmap.org/pbf/planet-latest.osm.pbf}"
DATADIR="${DATA_DIR:-/tmp/polarmap}"
EPSG=3995   # should be both a valid EPSG code and valid PostGIS SRID
BBOX="-180,30,180,90"           # latlon xmin,ymin,xmax,ymax
BBOX_OGR="${BBOX//,/ }"         # like $BBOX, but no commas

PG_DBNAME="${PG_DBNAME:-polarmap}"
PG_USER="${PG_USER:-postgres}"
PG_HOST="${PG_HOST:-localhost}"
PG_PORT=${PG_PORT:-5432}
PSQL="psql -U $PG_USER -h $PG_HOST -p $PG_PORT"
PSQLD="$PSQL -d $PG_DBNAME"

PROCS=${PROCS:-$(parallel --number-of-cores)}
