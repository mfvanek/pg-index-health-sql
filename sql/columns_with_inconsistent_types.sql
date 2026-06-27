/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds columns in different tables that share the same name but have different data types.
-- Inconsistent types for the same column name make joins and application code error-prone.
-- Primary keys (e.g. 'id') are intentionally not excluded to force a single type for all such columns within a schema.
--
-- Similar to schemacrawler.tools.linter.LinterColumnTypes https://www.schemacrawler.com/lint.html
with
    columns_info as (
        select
            pc.oid::regclass::text as table_name,
            col.attnotnull as column_not_null,
            col.atttypid::regtype::text as column_type,
            col.attname as raw_column_name
        from
            pg_catalog.pg_class pc
            inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
            inner join pg_catalog.pg_attribute col on col.attrelid = pc.oid
        where
            pc.relkind in ('r', 'p') and
            not pc.relispartition and
            col.attnum > 0 and /* to filter out system columns such as oid, ctid, xmin, xmax, etc. */
            not col.attisdropped and
            nsp.nspname = :schema_name_param::text
    )

select
    ci.table_name,
    ci.column_not_null,
    ci.column_type,
    quote_ident(ci.raw_column_name) as column_name
from
    columns_info ci
where
    ci.raw_column_name in (
        select inner_ci.raw_column_name
        from columns_info inner_ci
        group by inner_ci.raw_column_name
        having count(distinct inner_ci.column_type) > 1
    )
order by column_name, table_name;
