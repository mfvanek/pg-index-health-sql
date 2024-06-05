/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds indexes that contains boolean values.
select
    pi.indrelid::regclass::text as table_name,
    pi.indexrelid::regclass::text as index_name,
    col.attname as column_name,
    col.attnotnull as column_not_null,
    pg_relation_size(pi.indexrelid) as index_size
from
    pg_catalog.pg_index pi
    inner join pg_catalog.pg_class pc on pc.oid = pi.indexrelid
    inner join pg_catalog.pg_namespace pn on pn.oid = pc.relnamespace
    inner join pg_catalog.pg_attribute col on col.attrelid = pi.indrelid and col.attnum = any(pi.indkey)
where
    pn.nspname = :schema_name_param::text and
    not pi.indisunique and
    pi.indisready and
    pi.indisvalid and
    col.atttypid = 'boolean'::regtype
order by table_name, index_name;
