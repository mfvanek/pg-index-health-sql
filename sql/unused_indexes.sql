/*
 * Copyright (c) 2019-2020. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds potentially unused indexes.
-- This sql query have to be executed on all hosts in the cluster.
-- The final result can be obtained as an intersection of results from all hosts.
with foreign_key_indexes as (
    select i.indexrelid
    from pg_catalog.pg_constraint c
             join lateral unnest(c.conkey) with ordinality as u(attnum, attposition) on true
             join pg_catalog.pg_index i on i.indrelid = c.conrelid and (c.conkey::int[] <@ i.indkey::int[])
    where c.contype = 'f'
)
select psui.relid::regclass::text as table_name,
    psui.indexrelid::regclass::text as index_name,
    pg_relation_size(i.indexrelid) as index_size,
    psui.idx_scan as index_scans
from pg_catalog.pg_stat_user_indexes psui
         join pg_catalog.pg_index i on psui.indexrelid = i.indexrelid
where psui.schemaname = :schema_name_param::text
  and not i.indisunique
  and i.indexrelid not in (select * from foreign_key_indexes) /*retain indexes on foreign keys*/
  and psui.idx_scan < 50::integer
order by psui.relname, pg_relation_size(i.indexrelid) desc;
