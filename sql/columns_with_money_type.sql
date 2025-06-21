/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds columns of type 'money'.
-- Use `numeric` type instead (possibly with the currency being used in an adjacent column).
--
-- Money type doesn't handle fractions of a cent (or equivalents in other currencies),
-- it's rounding behavior is probably not what you want.
-- It doesn't store a currency with the value, rather assuming
-- that all money columns contain the currency specified by the database's lc_monetary locale setting.
-- If you change the lc_monetary setting for any reason, all money columns will contain the wrong value.
--
-- See https://wiki.postgresql.org/wiki/Don%27t_Do_This#Don.27t_use_money
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
    col.attnum > 0 and /* to filter out system columns */
    not col.attisdropped and
    col.atttypid = 'money'::regtype and
    nsp.nspname = :schema_name_param::text
order by table_name, column_name;
