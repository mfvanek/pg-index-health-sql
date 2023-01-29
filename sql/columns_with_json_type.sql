/*
 * Copyright (c) 2019-2023. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds columns of type 'json'. Use 'jsonb' instead.
--
-- See also https://www.postgresql.org/docs/current/datatype-json.html
-- and https://medium.com/geekculture/postgres-jsonb-usage-and-performance-analysis-cdbd1242a018
select
    t.oid::regclass::text as table_name,
    col.attname::text as column_name,
    col.attnotnull as column_not_null
from
    pg_catalog.pg_class t
    join pg_catalog.pg_namespace nsp on nsp.oid = t.relnamespace
    join pg_catalog.pg_attribute col on col.attrelid = t.oid
where
    t.relkind = 'r' and
    col.attnum > 0 and /* to filter out system columns such as oid, ctid, xmin, xmax, etc. */
    not col.attisdropped and
    col.atttypid = 'json'::regtype and
    nsp.nspname = :schema_name_param::text
order by t.oid::regclass::text, col.attname::text;
