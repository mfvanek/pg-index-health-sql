/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds tables that are not linked to other tables.
--
-- These are often service tables that are not part of the project, or
-- tables that are no longer in use or were created by mistake, but were not deleted in a timely manner.
--
-- Based on query from https://habr.com/ru/articles/803841/
with
    nsp as (
        select
            nsp.oid,
            nsp.nspname
        from pg_catalog.pg_namespace nsp
        where
            nsp.nspname = :schema_name_param::text
    ),

    fkeys as (
        select c.conrelid
        from
            pg_catalog.pg_constraint c
            inner join nsp on nsp.oid = c.connamespace
        where
            c.contype = 'f'

        union

        select c.confrelid
        from
            pg_catalog.pg_constraint c
            inner join nsp on nsp.oid = c.connamespace
        where
            c.contype = 'f'
    )

select
    pc.oid::regclass::text as table_name,
    pg_table_size(pc.oid) as table_size
from
    pg_catalog.pg_class pc
    inner join nsp on nsp.oid = pc.relnamespace
where
    pc.relkind in ('r', 'p') and
    not pc.relispartition and
    pc.oid not in (select * from fkeys)
order by table_name;
