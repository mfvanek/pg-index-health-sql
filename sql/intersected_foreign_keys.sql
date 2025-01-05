/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds partially identical foreign keys (with overlapping sets of columns).
--
-- Based on query from https://habr.com/ru/articles/803841/
with
    fk_with_attributes as (
        select
            c.conname as constraint_name,
            c.conrelid as table_oid,
            c.confrelid as foreign_table_oid,
            u.attposition,
            col.attname,
            col.attnotnull
        from
            pg_catalog.pg_constraint c
            inner join pg_catalog.pg_namespace nsp on nsp.oid = c.connamespace
            inner join lateral unnest(c.conkey) with ordinality u(attnum, attposition) on true
            inner join pg_catalog.pg_attribute col on col.attrelid = c.conrelid and col.attnum = u.attnum
        where
            c.contype = 'f' and
            nsp.nspname = :schema_name_param::text
    ),

    fk_with_attributes_grouped as (
        select
            constraint_name,
            table_oid,
            foreign_table_oid,
            array_agg(attname::text || ',' || attnotnull::text order by attposition) as columns
        from fk_with_attributes
        group by constraint_name, table_oid, foreign_table_oid
    )

select
    c1.table_oid::regclass::text as table_name,
    c1.constraint_name,
    c1.columns,
    c2.constraint_name as intersected_constraint_name,
    c2.columns as intersected_constraint_columns
from
    fk_with_attributes_grouped c1
    inner join fk_with_attributes_grouped c2
        on c2.constraint_name > c1.constraint_name and /* to prevent duplicated rows in output */
        c2.table_oid = c1.table_oid and
        c2.foreign_table_oid = c1.foreign_table_oid and
        c2.columns && c1.columns /* arrays overlap/have any elements in common? */
where
    c2.columns != c1.columns /* skip full duplicates */
order by table_name, c1.constraint_name, c2.constraint_name;
