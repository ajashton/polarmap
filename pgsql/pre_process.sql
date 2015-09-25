--alter table planet_osm_point add column label_line geometry;

alter table ne_10m_admin_0_countries add column geom_pt geometry(point);
create index ne_10m_admin_0_countries_geom_pt on ne_10m_admin_0_countries using gist (geom_pt);

alter table ne_10m_admin_1_states_provinces_shp add column geom_pt geometry(point);
create index ne_10m_admin_1_states_provinces_shp_geom_pt on ne_10m_admin_1_states_provinces_shp using gist (geom_pt);

alter table ne_10m_populated_places_simple add column label_line geometry;

create index grid_geom on grid using gist (geom);
create index mask_geom on mask using gist (geom);
