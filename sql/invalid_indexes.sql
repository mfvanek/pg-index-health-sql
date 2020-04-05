/*
 * Copyright (c) 2019-2020. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds invalid indexes that might have appeared as a result of
-- unsuccessful execution of the 'create index concurrently' command.
select x.indrelid::regclass as table_name,
    x.indexrelid::regclass as index_name
from pg_catalog.pg_index x
         join pg_catalog.pg_stat_all_indexes psai on x.indexrelid = psai.indexrelid
where psai.schemaname = :schema_name_param::text
  and x.indisvalid = false;
