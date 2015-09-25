-- IMPORTANT: this file is not meant to be run directly.

-- This file is multi-processed in parallel and requires that statements
-- are written to work well being run multiple times at once. At run-time
-- the variables :cores and :mod are available to allow you to split up
-- your statements by id based on the number of processes being run. In
-- most cases you can use them by adding a condition like this:
-- [...] WHERE (gid % :procs) = :proc [...]

update ne_10m_admin_0_countries
set geom_pt = ST_PointOnSurface(LargestPart(geom))
where (ogc_fid % :procs) = :proc;

update ne_10m_admin_1_states_provinces_shp
set geom_pt = ST_PointOnSurface(LargestPart(geom))
where (ogc_fid % :procs) = :proc;

update ne_10m_populated_places_simple
set label_line = point_label_arc(name, geom)
where (ogc_fid % :procs) = :proc;
