/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds tables that have all columns besides the primary key that are nullable.
-- Such tables may contain no useful data and could indicate a schema design smell.
--
-- Similar to schemacrawler.tools.linter.LinterTableAllNullableColumns https://www.schemacrawler.com/lint.html
with
    target_tables as (
        select pc.oid
        from
            pg_catalog.pg_class pc
            inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
        where
            nsp.nspname = :schema_name_param::text and
            pc.relkind in ('r', 'p') and
            not pc.relispartition
    ),

    pk_columns as (
        select
            c.conrelid as table_oid,
            array_agg(a.attnum) as pk_attnums
        from
            pg_catalog.pg_constraint c
            inner join target_tables t on t.oid = c.conrelid
            inner join pg_catalog.pg_attribute a on a.attrelid = t.oid and a.attnum = any(c.conkey)
        where
            c.contype = 'p'
        group by c.conrelid
    ),

    all_nullable as (
        select
            t.oid as table_oid,
            count(*) filter (where pk.pk_attnums is null or a.attnum <> all(pk.pk_attnums)) as nonpk_count,
            bool_and(
                a.attnotnull = false or
                a.attnum = any(coalesce(pk.pk_attnums, '{}'))
            ) as all_nonpk_nullable
        from
            target_tables t
            inner join pg_catalog.pg_attribute a on a.attrelid = t.oid
            left join pk_columns pk on pk.table_oid = t.oid
        where
            a.attnum > 0 and
            not a.attisdropped
        group by t.oid
    )

select
    a.table_oid::regclass::text as table_name,
    pg_table_size(a.table_oid) as table_size
from
    all_nullable a
where
    a.all_nonpk_nullable = true and
    a.nonpk_count > 0 /* ensure there is at least one non-pk column */
order by table_name;
