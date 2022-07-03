/*
 * Copyright (c) 2019-2022. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds tables that don't have a description. See also https://www.postgresql.org/docs/current/sql-comment.html
select
    pc.oid::regclass::text as table_name,
    pg_table_size(pc.oid) as table_size
from pg_catalog.pg_class pc
    join pg_catalog.pg_namespace pn on pc.relnamespace = pn.oid
where
    pc.relkind = 'r' and
    (obj_description(pc.oid) is null or length(trim(obj_description(pc.oid))) = 0) and
    pn.nspname = :schema_name_param::text
order by pc.oid::regclass::text;
