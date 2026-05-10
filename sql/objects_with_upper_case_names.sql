/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds database objects whose names contain uppercase letters.
-- Prefer names_like_this over NamesLikeThis.
-- PostgreSQL folds unquoted identifiers to lowercase, so using uppercase forces you to always quote the identifier.
--
-- See also https://wiki.postgresql.org/wiki/Don%27t_Do_This#Don.27t_use_upper_case_table_or_column_names
with
    nsp as (
        select
            nsp.oid,
            nsp.nspname
        from pg_catalog.pg_namespace nsp
        where
            nsp.nspname = :schema_name_param::text
    ),

    upper_case_names as (
        select
            pc.oid::regclass::text as object_name,
            case pc.relkind
                when 'r' then 'table'
                when 'i' then 'index'
                when 'S' then 'sequence'
                when 'v' then 'view'
                when 'm' then 'materialized view'
                when 'p' then 'partitioned table'
                when 'I' then 'partitioned index'
            end as object_type
        from
            pg_catalog.pg_class pc
            inner join nsp on nsp.oid = pc.relnamespace
        where
            pc.relkind in ('r', 'i', 'S', 'v', 'm', 'p', 'I') and
            /* decided not to filter by the pc.relispartition field here */
            pc.relname ~ '[A-Z]'

        union all

        select
            case when nsp.nspname = 'public' then quote_ident(p.proname) else quote_ident(nsp.nspname) || '.' || quote_ident(p.proname) end as object_name,
            'function' as object_type
        from
            pg_catalog.pg_proc p
            inner join nsp on nsp.oid = p.pronamespace
        where
            p.proname ~ '[A-Z]'

        union all

        select
            case when nsp.nspname = 'public' then quote_ident(c.conname) else quote_ident(nsp.nspname) || '.' || quote_ident(c.conname) end as object_name,
            'constraint' as object_type
        from
            pg_catalog.pg_constraint c
            inner join nsp on nsp.oid = c.connamespace
        where
            c.conname ~ '[A-Z]' and
            c.conparentid = 0 and c.coninhcount = 0 /* not a constraint in a partition */

    )

select *
from upper_case_names
order by object_type, object_name;
