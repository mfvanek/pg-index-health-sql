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
-- See https://www.schemacrawler.com/lint.html
-- Similar to schemacrawler.tools.linter.LinterTableWithIncrementingColumns
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
    )

select
    table_name,
    pg_table_size(oid) as table_size,
    array_agg(quote_ident(attname) || ',' || attnotnull::text order by attposition) as columns
from column_patterns
group by oid, table_name, base_name
having count(*) >= 2
order by table_name, columns[1];
