create or replace function point_label_arc (
        _name text,
        _geom geometry(point)
    )
    returns geometry
    language plpgsql immutable as
$function$
declare
    _srid integer := ST_SRID(_geom);
    _angle float := ST_Y(ST_Transform(_geom, 4326));
begin
    return MakeArc(
        ST_Transform(ST_Translate(ST_Transform(_geom, 4326), _angle * -1, 0), _srid),
        _geom,
        ST_Transform(ST_Translate(ST_Transform(_geom, 4326), _angle, 0), _srid)
    );
end;
$function$;
