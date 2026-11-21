/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds indexes that contain boolean values.
-- Returns all columns of such an index in their original order.
select
    pi.indrelid::regclass::text as table_name,
    pi.indexrelid::regclass::text as index_name,
    pg_relation_size(pi.indexrelid) as index_size,
    array_agg(quote_ident(col.attname) || ',' || col.attnotnull::text order by u.attposition) as columns
from
    pg_catalog.pg_index pi
    inner join pg_catalog.pg_class pc on pc.oid = pi.indexrelid
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
    inner join unnest(pi.indkey) with ordinality u(attnum, attposition) on true
    inner join pg_catalog.pg_attribute col on col.attrelid = pi.indrelid and col.attnum = u.attnum
where
    nsp.nspname = :schema_name_param::text and
    not pi.indisunique and
    pi.indisvalid and
    not pc.relispartition and
    exists (
        select 1
        from pg_catalog.pg_attribute bool_col
        where
            bool_col.attrelid = pi.indrelid and
            /* only key columns: columns from the include clause (positions from indnkeyatts on) are not used for searching */
            bool_col.attnum = any((pi.indkey::int2[])[0:pi.indnkeyatts - 1]) and
            bool_col.atttypid = 'boolean'::regtype
    )
group by pi.indrelid, pi.indexrelid
order by table_name, index_name;
