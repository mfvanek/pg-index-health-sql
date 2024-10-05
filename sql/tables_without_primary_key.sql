/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds tables that don't have a primary key.
select
    pc.oid::regclass::text as table_name,
    pg_table_size(pc.oid) as table_size
from
    pg_catalog.pg_class pc
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
where
    pc.relkind = 'r' and
    pc.oid not in (
        select c.conrelid as table_oid
        from pg_catalog.pg_constraint c
        where c.contype = 'p'
    ) and
    nsp.nspname = :schema_name_param::text
order by pc.oid::regclass::text;
