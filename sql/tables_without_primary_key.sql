/*
 * Copyright (c) 2019-2020. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

select psat.relid::regclass::text as table_name,
    pg_table_size(psat.relid) as table_size
from pg_catalog.pg_stat_all_tables psat
where psat.schemaname = :schema_name_param::text
  and psat.relid::regclass not in (
    select c.conrelid::regclass as table_name
    from pg_catalog.pg_constraint c
    where c.contype = 'p')
order by psat.relname::text;
