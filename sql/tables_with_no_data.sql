/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds tables that appear to be empty based on pg_catalog statistics.
-- relpages = 0 means no data pages are allocated; reltuples <= 0 means confirmed empty or never analyzed.
-- Note: tables that had rows deleted but not yet vacuumed will still have relpages > 0 and won't appear here.
select
    pc.oid::regclass::text as table_name,
    pg_table_size(pc.oid) as table_size
from
    pg_catalog.pg_class pc
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
where
    pc.relkind in ('r', 'p') and
    not pc.relispartition and
    pc.relpages = 0 and
    pc.reltuples <= 0 and
    nsp.nspname = :schema_name_param::text
order by table_name;
