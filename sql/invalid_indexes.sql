/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds invalid indexes that might have appeared as a result of
-- unsuccessful execution of the 'create index concurrently' command.
-- Indexes on child partitions are intentionally not excluded: an invalid index can be attached
-- to a partitioned (parent) index, and then it is the child index that has to be rebuilt.
select
    pi.indrelid::regclass::text as table_name,
    pi.indexrelid::regclass::text as index_name,
    pg_relation_size(pi.indexrelid) as index_size
from
    pg_catalog.pg_index pi
    inner join pg_catalog.pg_class pc on pc.oid = pi.indexrelid
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
where
    nsp.nspname = :schema_name_param::text and
    not pi.indisvalid
order by table_name, index_name;
