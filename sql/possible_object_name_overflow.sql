/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds objects whose names have a length of max_identifier_length (usually it is 63).
-- The problem is that Postgres silently truncates such long names.
-- For example, if you have a migration where you are trying to create two objects with very long names
-- that start the same way (such as an index or constraint) and you use the "if not exists" statement,
-- you might end up with only one object in the database instead of two.
--
-- If there is an object with a name of maximum length in the database, then an overflow may have occurred.
-- It is advisable to avoid such situations and use shorter names.
--
-- See https://www.postgresql.org/docs/current/runtime-config-preset.html#GUC-MAX-IDENTIFIER-LENGTH
-- See https://www.postgresql.org/docs/current/catalog-pg-class.html
with
    t as (
        select current_setting('max_identifier_length')::int as max_identifier_length
    ),

    long_names as (
        select
            pc.oid::regclass::text as object_name,
            case pc.relkind
                when 'r' then 'table'
                when 'i' then 'index'
                when 'S' then 'sequence'
                when 'v' then 'view'
                when 'm' then 'materialized view'
            end as object_type
        from pg_catalog.pg_class pc
        inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
        inner join t on t.max_identifier_length = length(pc.relname)
        where
            pc.relkind in ('r', 'i', 'S', 'v', 'm') and
            nsp.nspname = :schema_name_param::text

        union all

        select
            case when nsp.nspname = 'public' then p.proname else nsp.nspname || '.' || p.proname end as object_name,
            'function' as object_type
        from pg_proc p
        inner join pg_catalog.pg_namespace nsp on nsp.oid = p.pronamespace
        inner join t on t.max_identifier_length = length(p.proname)
        where
            nsp.nspname = :schema_name_param::text

        union all

        select
            case when nsp.nspname = 'public' then c.conname else nsp.nspname || '.' || c.conname end as object_name,
            'constraint' as object_type
        from pg_constraint c
        inner join pg_catalog.pg_namespace nsp on c.connamespace = nsp.oid
        inner join t on t.max_identifier_length = length(c.conname)
        where
            nsp.nspname = :schema_name_param::text
    )

select *
from long_names
order by object_type, object_name;
