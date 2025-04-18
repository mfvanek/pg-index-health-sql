/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds invalid indexes that might have appeared as a result of
-- unsuccessful execution of the 'create index concurrently' command.
select
    x.indrelid::regclass::text as table_name,
    x.indexrelid::regclass::text as index_name
from
    pg_catalog.pg_index x
    inner join pg_catalog.pg_stat_all_indexes psai on psai.indexrelid = x.indexrelid
where
    psai.schemaname = :schema_name_param::text and
    x.indisvalid = false
order by table_name, index_name;
