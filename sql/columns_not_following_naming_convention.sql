/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds columns whose names do not follow naming convention (that have to be enclosed in double-quotes).
-- You should avoid using quoted column names.
--
-- See https://www.postgresql.org/docs/17/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS
-- See also https://lerner.co.il/2013/11/30/quoting-postgresql/
-- See also https://wiki.postgresql.org/wiki/Don%27t_Do_This#Don.27t_use_upper_case_table_or_column_names
select
    t.oid::regclass::text as table_name,
    col.attnotnull as column_not_null,
    quote_ident(col.attname) as column_name
from
    pg_catalog.pg_class t
    inner join pg_catalog.pg_namespace nsp on nsp.oid = t.relnamespace
    inner join pg_catalog.pg_attribute col on col.attrelid = t.oid
where
    t.relkind in ('r', 'p') and
    not t.relispartition and
    col.attnum > 0 and /* to filter out system columns such as oid, ctid, xmin, xmax, etc. */
    not col.attisdropped and
    (col.attname ~ '[A-Z]' or col.attname ~ '[^a-z0-9_]') and /* column name has characters that require quoting */
    nsp.nspname = :schema_name_param::text
order by table_name, column_name;
