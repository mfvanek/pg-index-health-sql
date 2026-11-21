/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds foreign keys for which no index was created in the referencing (child) table.
-- This will cause the child table to be scanned sequentially when deleting an entry from the referenced (parent) table.
-- Invalid indexes and BRIN indexes are not considered as covering the foreign key.
-- Partial indexes are considered as covering the foreign key only if their predicate consists solely of
-- "fk_column IS NOT NULL" conditions joined by AND: such a predicate is implied by the equality lookup
-- that PostgreSQL runs on the child table, while any other predicate makes the index unusable for that lookup.
with
    foreign_keys as (
        select
            c.oid,
            c.conrelid,
            c.conname,
            c.conkey
        from
            pg_catalog.pg_constraint c
            inner join pg_catalog.pg_namespace nsp on nsp.oid = c.connamespace
        where
            c.contype = 'f' and
            c.conparentid = 0 and c.coninhcount = 0 and /* not a constraint in a partition */
            nsp.nspname = :schema_name_param::text
    ),

    indexes as (
        /* valid indexes on the referencing tables */
        select
            pi.indexrelid,
            pi.indrelid,
            pi.indkey::int[] as index_columns,
            pg_catalog.pg_get_expr(pi.indpred, pi.indrelid) as predicate
        from
            pg_catalog.pg_index pi
            inner join pg_catalog.pg_class pc on pc.oid = pi.indexrelid
            inner join pg_catalog.pg_am am on am.oid = pc.relam
        where
            pi.indisvalid and /* invalid index is not used by the planner */
            am.amname != 'brin' and /* brin index stores block ranges and does not speed up lookups by foreign key */
            pi.indrelid in (select fk.conrelid from foreign_keys fk)
    ),

    not_null_partial_indexes as (
        /* partial indexes with a predicate like "(a IS NOT NULL) AND (b IS NOT NULL)" and the columns tested in it */
        select
            i.indexrelid,
            array_agg(col.attnum::int) as predicate_columns
        from
            indexes i
            inner join lateral regexp_matches(i.predicate, '\(("(?:[^"]|"")+"|[^()" ]+) IS NOT NULL\)', 'g') m(cols) on true
            left join pg_catalog.pg_attribute col on col.attrelid = i.indrelid and quote_ident(col.attname) = m.cols[1]
        where
            i.predicate is not null and
            /* nothing but AND, parentheses and spaces remains after removing all "column IS NOT NULL" conditions */
            btrim(regexp_replace(regexp_replace(i.predicate, '\(("(?:[^"]|"")+"|[^()" ]+) IS NOT NULL\)', '', 'g'), '\s+AND\s+|[()\s]', '', 'g')) = ''
        group by i.indexrelid
        having count(*) = count(col.attnum) /* every tested column is resolved */
    ),

    usable_indexes as (
        select
            i.indrelid,
            i.index_columns,
            coalesce(nn.predicate_columns, '{}'::int[]) as predicate_columns
        from
            indexes i
            left join not_null_partial_indexes nn on nn.indexrelid = i.indexrelid
        where
            i.predicate is null or nn.indexrelid is not null
    )

select
    fk.conrelid::regclass::text as table_name,
    quote_ident(fk.conname) as constraint_name,
    array_agg(quote_ident(col.attname) || ',' || col.attnotnull::text order by u.attposition) as columns
from
    foreign_keys fk
    inner join lateral unnest(fk.conkey) with ordinality u(attnum, attposition) on true
    inner join pg_catalog.pg_attribute col on col.attrelid = fk.conrelid and col.attnum = u.attnum
where
    not exists(
        select 1
        from usable_indexes ui
        where
            ui.indrelid = fk.conrelid and
            (fk.conkey::int[] <@ ui.index_columns) and /* all columns of foreign key have to present in index */
            ui.index_columns[0] = any(fk.conkey::int[]) and /* index starts with any column of foreign key: for equality lookup the order of columns does not matter */
            (ui.predicate_columns <@ fk.conkey::int[]) /* index predicate checks only foreign key columns for not null */
    )
group by fk.conrelid, fk.conname, fk.oid
order by table_name, constraint_name;
