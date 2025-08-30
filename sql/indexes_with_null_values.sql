/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds indexes that can contain null values.
select
    pi.indrelid::regclass::text as table_name,
    pi.indexrelid::regclass::text as index_name,
    string_agg(quote_ident(a.attname), ', ') as nullable_fields, /* in fact, there will always be only one column */
    pg_relation_size(pi.indexrelid) as index_size
from
    pg_catalog.pg_index pi
    inner join pg_catalog.pg_class ic on ic.oid = pi.indexrelid
    inner join pg_catalog.pg_namespace nsp on nsp.oid = ic.relnamespace
    inner join pg_catalog.pg_attribute a on a.attrelid = pi.indrelid and a.attnum = any(pi.indkey)
where
    not pi.indisunique and
    not a.attnotnull and
    not ic.relispartition and
    nsp.nspname = :schema_name_param::text and
    array_position(pi.indkey, a.attnum) = 0 and /* only for the first segment */
    (pi.indpred is null or (position(lower(a.attname) in lower(pg_get_expr(pi.indpred, pi.indrelid))) = 0))
group by pi.indrelid, pi.indexrelid, pi.indpred
order by table_name, index_name;
