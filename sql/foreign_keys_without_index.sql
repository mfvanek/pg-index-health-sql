/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds foreign keys for which no index was created in the referencing (child) table.
-- This will cause the child table to be scanned sequentially when deleting an entry from the referenced (parent) table.
select
    c.conrelid::regclass as table_name,
    c.conname as constraint_name,
    array_agg(col.attname || ', ' || col.attnotnull::text order by u.attposition) as columns
from
    pg_catalog.pg_constraint c
    inner join lateral unnest(c.conkey) with ordinality u(attnum, attposition) on true
    inner join pg_catalog.pg_class t on t.oid = c.conrelid
    inner join pg_catalog.pg_namespace nsp on nsp.oid = t.relnamespace
    inner join pg_catalog.pg_attribute col on col.attrelid = t.oid and col.attnum = u.attnum
where
    c.contype = 'f' and
    nsp.nspname = :schema_name_param::text and
    not exists(
        select 1
        from pg_catalog.pg_index pi
        where
            pi.indrelid = c.conrelid and
            (c.conkey::int[] <@ pi.indkey::int[]) and /* all columns of foreign key have to present in index */
            array_position(pi.indkey::int[], (c.conkey::int[])[1]) = 0 /* ordering of columns in foreign key and in index is the same */
    )
group by c.conrelid, c.conname, c.oid
order by (c.conrelid::regclass)::text, columns;
