-- IMPORTANT: this file is not meant to be run directly.

-- This file is multi-processed in parallel and requires that statements
-- are written to work well being run multiple times at once. At run-time
-- the variables :cores and :mod are available to allow you to split up
-- your statements by id based on the number of processes being run. In
-- most cases you can use them by adding a condition like this:
-- [...] WHERE (gid % :procs) = :proc [...]

update planet_osm_point
set label_line = point_label_arc(name, way)
where place = 'city'
--        and (osm_id % :procs) = :proc
;
