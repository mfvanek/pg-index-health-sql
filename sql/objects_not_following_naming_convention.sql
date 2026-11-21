/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds objects whose names do not follow naming convention (that have to be enclosed in double-quotes).
-- Also finds database objects whose names contain uppercase letters.
-- You should avoid using quoted identifiers. Prefer names_like_this over NamesLike-this.
--
-- See https://www.postgresql.org/docs/17/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS
-- See also https://lerner.co.il/2013/11/30/quoting-postgresql/
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

    /* objects that belong to extensions: their names can't be changed by the user */
    ext_members as (
        select
            d.classid,
            d.objid
        from pg_catalog.pg_depend d
        where
            d.deptype = 'e'
    ),

    bad_names as (
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
            left join pg_catalog.pg_index pi on pi.indexrelid = pc.oid
        where
            pc.relkind in ('r', 'i', 'S', 'v', 'm', 'p', 'I') and
            /* decided not to filter by the pc.relispartition field here */
            pc.relname !~ '^[a-z_][a-z0-9_]*$' and /* the object name has characters that require quoting */
            /* indexes are not extension members themselves, so they are checked via their table */
            not exists (
                select 1
                from ext_members e
                where
                    e.classid = 'pg_catalog.pg_class'::regclass and
                    e.objid in (pc.oid, pi.indrelid)
            )

        union all

        select
            case when nsp.nspname = 'public' then quote_ident(p.proname) else quote_ident(nsp.nspname) || '.' || quote_ident(p.proname) end as object_name,
            'function' as object_type
        from
            pg_catalog.pg_proc p
            inner join nsp on nsp.oid = p.pronamespace
        where
            p.proname !~ '^[a-z_][a-z0-9_]*$' and
            not exists (
                select 1
                from ext_members e
                where
                    e.classid = 'pg_catalog.pg_proc'::regclass and
                    e.objid = p.oid
            )

        union all

        select
            case when nsp.nspname = 'public' then quote_ident(c.conname) else quote_ident(nsp.nspname) || '.' || quote_ident(c.conname) end as object_name,
            'constraint' as object_type
        from
            pg_catalog.pg_constraint c
            inner join nsp on nsp.oid = c.connamespace
        where
            c.conname !~ '^[a-z_][a-z0-9_]*$' and
            c.conparentid = 0 and c.coninhcount = 0 and /* not a constraint in a partition */
            /* constraints are not extension members themselves, so they are checked via their table or domain */
            not exists (
                select 1
                from ext_members e
                where
                    (e.classid = 'pg_catalog.pg_class'::regclass and e.objid = c.conrelid) or
                    (e.classid = 'pg_catalog.pg_type'::regclass and e.objid = c.contypid)
            )
    )

select *
from bad_names
order by object_type, object_name;
