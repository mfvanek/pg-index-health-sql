/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds tables with incrementing column names (for example, contact1, contact2, contact3),
-- which indicates de-normalization that could be replaced with a separate child table and a foreign key.
-- Groups columns by their shared base name (the non-numeric prefix) and reports any group of two or more.
--
-- Similar to schemacrawler.tools.linter.LinterTableWithIncrementingColumns
-- https://www.schemacrawler.com/lint.html
with
    column_patterns as (
        select
            pc.oid,
            pc.oid::regclass::text as table_name,
            col.attname,
            col.attnotnull,
            col.attnum as attposition,
            regexp_replace(col.attname, '\d+$', '') as base_name
        from
            pg_catalog.pg_class pc
            inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
            inner join pg_catalog.pg_attribute col on col.attrelid = pc.oid
        where
            pc.relkind in ('r', 'p') and
            not pc.relispartition and
            col.attnum > 0 and /* to filter out system columns such as oid, ctid, xmin, xmax, etc. */
            not col.attisdropped and
            col.attname ~ '^\D+\d+$' and /* column name ends with digits and starts with at least one non-digit */
            nsp.nspname = :schema_name_param::text
    ),

    groups_with_two_or_more as (
        select
            oid,
            base_name
        from column_patterns
        group by oid, base_name
        having count(*) >= 2
    )

select
    cp.table_name,
    pg_table_size(cp.oid) as table_size,
    array_agg(quote_ident(cp.attname) || ',' || cp.attnotnull::text order by cp.attposition) as columns
from
    column_patterns cp
    inner join groups_with_two_or_more g on g.oid = cp.oid and g.base_name = cp.base_name
group by cp.oid, cp.table_name
order by cp.table_name;
