/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds indexes that have a redundant predicate with the where-clause 'column is not null' for the not null column.
select
    pc.oid::regclass::text as table_name,
    pi.indexrelid::regclass::text as index_name,
    pg_relation_size(pi.indexrelid) as index_size,
    array_agg(quote_ident(a.attname) || ',' || a.attnotnull::text order by u.ordinality) as columns
from
    pg_index pi
    inner join pg_class pc on pc.oid = pi.indrelid
    inner join pg_namespace nsp on nsp.oid = pc.relnamespace
    inner join unnest(pi.indkey) with ordinality as u(attnum, ordinality) on true
    inner join pg_attribute a on a.attrelid = pc.oid and a.attnum = u.attnum
where
    pc.relkind in ('r', 'p') and /* regular and partitioned tables */
    not pc.relispartition and
    pi.indpred is not null and
    exists (
        select 1
        from
            unnest(pi.indkey) as k(attnum)
            inner join pg_attribute att on att.attrelid = pc.oid and att.attnum = k.attnum
        where
            att.attnotnull = true and
            pg_get_indexdef(pi.indexrelid) ilike '%where%' || quote_ident(att.attname) || ' is not null%'
    ) and
    nsp.nspname = :schema_name_param::text
group by pc.oid, pi.indexrelid
order by table_name, index_name;
