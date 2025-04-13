/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds columns that don't have a description.
-- See also https://www.postgresql.org/docs/current/sql-comment.html
select
    pc.oid::regclass::text as table_name,
    col.attnotnull as column_not_null,
    quote_ident(col.attname::text) as column_name
from
    pg_catalog.pg_class pc
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
    inner join pg_catalog.pg_attribute col on col.attrelid = pc.oid
where
    pc.relkind in ('r', 'p') and
    not pc.relispartition and
    col.attnum > 0 and /* to filter out system columns such as oid, ctid, xmin, xmax, etc. */
    not col.attisdropped and
    (col_description(pc.oid, col.attnum) is null or length(trim(col_description(pc.oid, col.attnum))) = 0) and
    nsp.nspname = :schema_name_param::text
order by table_name, column_name;
