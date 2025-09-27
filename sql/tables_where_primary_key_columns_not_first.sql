/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds tables where the primary key columns are not first.
--
-- Putting the primary key as the first column is mostly a style and convention thing rather than a technical requirement.
-- It improves readability, consistency, and expectations, especially in teams or large schemas.
-- It helps with tooling, introspection, and makes schema definitions easier to understand at a glance.
--
-- Similar to schemacrawler.tools.linter.LinterTableWithPrimaryKeyNotFirst https://www.schemacrawler.com/lint.html
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

    first_columns as (
        select
            t.oid as table_oid,
            a.attname as first_column
        from
            target_tables t
            inner join pg_catalog.pg_attribute a on a.attrelid = t.oid and a.attnum > 0 and not a.attisdropped
        where
            a.attnum = (
                select min(att.attnum)
                from pg_catalog.pg_attribute att
                where
                    att.attrelid = t.oid and
                    att.attnum > 0 and
                    not att.attisdropped
            )
    ),

    pk_columns as (
        select
            c.conrelid as table_oid,
            array_agg(a.attname order by a.attnum) as pk_columns
        from
            pg_catalog.pg_constraint c
            inner join target_tables t on t.oid = c.conrelid
            inner join pg_catalog.pg_attribute a on a.attrelid = t.oid and a.attnum = any(c.conkey)
        where
            c.contype = 'p'
        group by c.conrelid
    )

select
    f.table_oid::regclass::text as table_name,
    pg_table_size(f.table_oid) as table_size
from
    first_columns f
    inner join pk_columns p on p.table_oid = f.table_oid
where
    f.first_column <> p.pk_columns[1]
order by table_name;
