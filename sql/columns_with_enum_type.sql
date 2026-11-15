/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds columns of an enum type (including arrays of enums).
-- Prefer a 'text' column with a check constraint or a foreign key to a lookup table instead.
--
-- New values can be added to an enum, but existing values cannot be removed or reordered.
-- Removing a value requires recreating the type and rewriting all dependent columns and indexes.
-- Any change to the list of allowed values is a DDL migration rather than a simple data update.
-- Enums are less flexible than foreign keys to lookup tables.
--
-- See https://www.postgresql.org/docs/current/datatype-enum.html
-- See also https://github.com/kristiandupont/schemalint/blob/main/src/rules/README.md#prefer-text-with-check-to-enum
select
    pc.oid::regclass::text as table_name,
    col.attnotnull as column_not_null,
    col.atttypid::regtype::text as column_type,
    quote_ident(col.attname) as column_name
from
    pg_catalog.pg_class pc
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
    inner join pg_catalog.pg_attribute col on col.attrelid = pc.oid
    inner join pg_catalog.pg_type t on t.oid = col.atttypid
    left join pg_catalog.pg_type et on et.oid = t.typelem /* element type for arrays */
where
    pc.relkind in ('r', 'p') and
    not pc.relispartition and
    col.attnum > 0 and /* to filter out system columns */
    not col.attisdropped and
    (t.typtype = 'e' or et.typtype = 'e') and
    nsp.nspname = :schema_name_param::text
order by table_name, column_name;
