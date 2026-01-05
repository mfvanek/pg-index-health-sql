/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds columns of type char, char(n), character(n) or bpchar(n).
--
-- Do not use the type 'char(n)'. You should use the type 'text' instead.
-- Any string you insert into a char(n) field will be padded with spaces to the declared width.
-- The space-padding does waste space but does not make operations on it any faster.
--
-- See https://wiki.postgresql.org/wiki/Don%27t_Do_This#Don't_use_char(n)
-- See https://www.postgresql.org/docs/current/datatype-character.html
-- See also https://squawkhq.com/docs/ban-char-field
select
    t.oid::regclass::text as table_name,
    col.attnotnull as column_not_null,
    col.atttypid::regtype::text as column_type,
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
    col.atttypid in ('character'::regtype, 'char'::regtype, 'bpchar'::regtype) and
    col.atttypmod > 0 and /* only for fixed length varchar (not varchar without n) */
    nsp.nspname = :schema_name_param::text
order by table_name, column_name;
