/*
 * Copyright (c) 2019-2022. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds columns that don't have a description. See also https://www.postgresql.org/docs/current/sql-comment.html
select
    t.oid::regclass::text as table_name,
    col.attname::text as column_name,
    col.attnotnull as column_not_null
from pg_catalog.pg_class t
    join pg_catalog.pg_namespace nsp on nsp.oid = t.relnamespace
    join pg_catalog.pg_attribute col on col.attrelid = t.oid
where
    t.relkind = 'r' and
    col.attnum > 0 and /* to filter out system columns such as oid, ctid, xmin, xmax, etc.*/
    not col.attisdropped and
    (col_description(t.oid, col.attnum) is null or length(trim(col_description(t.oid, col.attnum))) = 0) and
    nsp.nspname = :schema_name_param::text
order by t.oid::regclass::text, col.attname::text;
