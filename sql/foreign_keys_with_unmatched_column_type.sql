/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds foreign keys where the type of the constrained column does not match the type in the referenced table.
--
-- The column types in the referring and target relation must match.
-- For example, a column with the integer type should refer to a column with the integer type.
-- This eliminates unnecessary conversions at the DBMS level and in the application code,
-- and reduces the number of errors that may appear due to type inconsistencies in the future.
--
-- See https://www.postgresql.org/docs/current/catalog-pg-constraint.html
-- Based on query from https://habr.com/ru/articles/803841/
with
    fk_with_attributes as (
        select
            c.conname as constraint_name,
            c.conrelid as table_oid,
            c.confrelid as foreign_table_oid,
            u.attposition,
            col.attname,
            col.attnotnull,
            col.atttypid,
            col.atttypmod,
            foreign_u.attposition as foreign_attposition,
            foreign_col.attname as foreign_attname,
            foreign_col.attnotnull as foreign_attnotnull,
            foreign_col.atttypid as foreign_atttypid,
            foreign_col.atttypmod as foreign_atttypmod
        from
            pg_catalog.pg_constraint c
            inner join pg_catalog.pg_namespace nsp on nsp.oid = c.connamespace
            inner join lateral unnest(c.conkey) with ordinality u(attnum, attposition) on true
            inner join lateral unnest(c.confkey) with ordinality foreign_u(attnum, attposition) on foreign_u.attposition = u.attposition
            inner join pg_catalog.pg_attribute col on col.attrelid = c.conrelid and col.attnum = u.attnum
            inner join pg_catalog.pg_attribute foreign_col on foreign_col.attrelid = c.confrelid and foreign_col.attnum = foreign_u.attnum
        where
            c.contype = 'f' and
            c.conparentid = 0 and c.coninhcount = 0 and /* not a constraint in a partition */
            nsp.nspname = :schema_name_param::text
    ),

    fk_with_attributes_grouped as (
        select
            constraint_name,
            table_oid,
            foreign_table_oid,
            array_agg(attname::text || ',' || attnotnull::text order by attposition) as columns
        from fk_with_attributes
        where
            (atttypid != foreign_atttypid) or (atttypmod != foreign_atttypmod)
        group by constraint_name, table_oid, foreign_table_oid
    )

select
    table_oid::regclass::text as table_name,
    constraint_name,
    columns
from
    fk_with_attributes_grouped
order by table_name, constraint_name;
