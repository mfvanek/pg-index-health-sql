/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds columns of type 'timestamp (without time zone)' or 'timetz' in the specified schema.
-- Don't use the timestamp type to store timestamps, use timestamptz (also known as timestamp with time zone) instead.
-- Don't use the timetz type. You probably want timestamptz instead.
--
-- See https://wiki.postgresql.org/wiki/Don't_Do_This#Don.27t_use_timestamp_.28without_time_zone.29
-- See https://wiki.postgresql.org/wiki/Don't_Do_This#Don't_use_timetz
select
    t.oid::regclass::text as table_name,
    col.attnotnull as column_not_null,
    col.atttypid::regtype::text as column_type,
    quote_ident(col.attname) as column_name
from
    pg_catalog.pg_class t
    inner join pg_catalog.pg_namespace nsp on nsp.oid = t.relnamespace
    inner join pg_catalog.pg_attribute col on col.attrelid = t.oid
where
    t.relkind in ('r', 'p') and
    not t.relispartition and
    col.attnum > 0 and /* to filter out system columns */
    not col.attisdropped and
    col.atttypid in ('timestamp without time zone'::regtype, 'timetz'::regtype) and
    nsp.nspname = :schema_name_param::text
order by table_name, column_name;
