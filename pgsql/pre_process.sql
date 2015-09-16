alter table planet_osm_point add column label_line geometry;

alter table ne_10m_populated_places_simple add column label_line geometry;

create index grid_geom on grid using gist (geom);
create index mask_geom on mask using gist (geom);
