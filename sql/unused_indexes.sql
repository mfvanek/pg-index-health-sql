/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds potentially unused indexes.
-- This sql query have to be executed on all hosts in the cluster.
-- The final result can be obtained as an intersection of results from all hosts.
-- noqa: disable=RF02
with
    nsp as (
        select
            nsp.oid,
            nsp.nspname
        from pg_catalog.pg_namespace nsp
        where
            nsp.nspname = :schema_name_param::text
    ),

    foreign_key_indexes as (
        select i.indexrelid
        from
            pg_catalog.pg_constraint c
            inner join nsp on nsp.oid = c.connamespace
            inner join lateral unnest(c.conkey) with ordinality u(attnum, attposition) on true
            inner join pg_catalog.pg_index i on i.indrelid = c.conrelid and (c.conkey::int[] <@ i.indkey::int[])
        where c.contype = 'f'
    )

select
    psui.relid::regclass::text as table_name,
    psui.indexrelid::regclass::text as index_name,
    psui.idx_scan as index_scans,
    pg_relation_size(i.indexrelid) as index_size
from
    pg_catalog.pg_stat_user_indexes psui
    inner join pg_catalog.pg_index i on i.indexrelid = psui.indexrelid
where
    psui.schemaname in (select nspname from nsp) and
    not i.indisunique and
    i.indexrelid not in (select * from foreign_key_indexes) and /* retain indexes on foreign keys */
    psui.idx_scan < 50::integer
order by table_name, pg_relation_size(i.indexrelid) desc;
