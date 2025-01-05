/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds indexes that can contain null values.
select
    i.indrelid::regclass::text as table_name,
    i.indexrelid::regclass::text as index_name,
    string_agg(a.attname, ', ') as nullable_fields, /* in fact, there will always be only one column */
    pg_relation_size(i.indexrelid) as index_size
from
    pg_catalog.pg_index i
    inner join pg_catalog.pg_class ic on ic.oid = i.indexrelid
    inner join pg_catalog.pg_namespace nsp on nsp.oid = ic.relnamespace
    inner join pg_catalog.pg_attribute a on a.attrelid = i.indrelid and a.attnum = any(i.indkey)
where
    not i.indisunique and
    not a.attnotnull and
    not ic.relispartition and
    nsp.nspname = :schema_name_param::text and
    array_position(i.indkey, a.attnum) = 0 and /* only for first segment */
    (i.indpred is null or (position(lower(a.attname) in lower(pg_get_expr(i.indpred, i.indrelid))) = 0))
group by i.indrelid, i.indexrelid, i.indpred
order by table_name, index_name;
