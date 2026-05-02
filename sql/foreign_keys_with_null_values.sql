/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds multicolumn foreign keys where at least one of the referencing columns is nullable
-- and a match type on constraint is not MATCH FULL.
--
-- MATCH FULL will not allow one column of a multicolumn foreign key to be null unless all foreign key columns are null;
-- if they are all null, the row is not required to have a match in the referenced table.
-- MATCH SIMPLE (which is the default) allows any of the foreign key columns to be null;
-- if any of them are null, the row is not required to have a match in the referenced table.
--
-- See https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK
-- Based on a query from https://habr.com/ru/articles/803841/
with
    fk_with_attributes as (
        select
            c.conrelid as table_oid,
            u.attposition,
            col.attnotnull,
            quote_ident(col.attname) as column_name,
            quote_ident(c.conname) as constraint_name
        from
            pg_catalog.pg_constraint c
                inner join pg_catalog.pg_namespace nsp on nsp.oid = c.connamespace
                inner join lateral unnest(c.conkey) with ordinality u(attnum, attposition) on true
                inner join pg_catalog.pg_attribute col on col.attrelid = c.conrelid and col.attnum = u.attnum
        where
            c.contype = 'f' and
            array_length(c.conkey, 1) > 1 and
            c.confmatchtype <> 'f' and  /* not match full */
            c.conparentid = 0 and c.coninhcount = 0 and /* not a constraint in a partition */
            nsp.nspname = :schema_name_param::text
    ),

    fk_with_attributes_grouped as (
        select
            constraint_name,
            table_oid,
            array_agg(column_name || ',' || attnotnull::text order by attposition) as columns
        from fk_with_attributes
        group by constraint_name, table_oid
        having bool_or(attnotnull = false) /* at least one referencing column is nullable */
    )

select
    table_oid::regclass::text as table_name,
    constraint_name,
    columns
from
    fk_with_attributes_grouped
order by table_name, constraint_name;
