/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds invalid indexes that might have appeared as a result of
-- unsuccessful execution of the 'create index concurrently' command.
select
    pi.indrelid::regclass::text as table_name,
    pi.indexrelid::regclass::text as index_name,
    pg_relation_size(pi.indexrelid) as index_size
from
    pg_catalog.pg_index pi
    inner join pg_catalog.pg_stat_all_indexes psai on psai.indexrelid = pi.indexrelid
where
    psai.schemaname = :schema_name_param::text and
    pi.indisvalid = false
order by table_name, index_name;
