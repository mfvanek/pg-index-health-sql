/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
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
    inner join pg_catalog.pg_class pc on pc.oid = pi.indexrelid
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
    inner join pg_catalog.pg_attribute a on a.attrelid = pi.indrelid and a.attnum = any(pi.indkey)
where
    not pi.indisunique and
    not a.attnotnull and
    not pc.relispartition and
    nsp.nspname = :schema_name_param::text and
    array_position(pi.indkey, a.attnum) = 0 and /* only for the first segment */
    /* skip partial indexes whose predicate references the column (e.g. "col IS NOT NULL", "col = 'x'", "col > 0"): */
    /* such a predicate usually excludes nulls. Every column reference in the predicate tree is a VAR node with its attnum */
    (pi.indpred is null or pi.indpred::text !~ (':varattno ' || a.attnum || ' '))
group by pi.indrelid, pi.indexrelid, pi.indpred
order by table_name, index_name;
