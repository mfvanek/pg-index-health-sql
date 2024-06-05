/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds primary keys columns with serial type (smallserial/serial/bigserial)
-- Instead of old smallserial/serial/bigserial new "generated as identity" syntax should be used
-- for defining primary keys
-- Based on https://dba.stackexchange.com/questions/90555/postgresql-select-primary-key-as-serial-or-bigserial/
-- See also https://wiki.postgresql.org/wiki/Don't_Do_This#Don.27t_use_serial
-- and https://stackoverflow.com/questions/55300370/postgresql-serial-vs-identity
select
    col.attrelid::regclass as table_name,
    col.attname as column_name,
    col.attnotnull as column_not_null,
    case col.atttypid
        when 'int'::regtype then 'serial'
        when 'int8'::regtype then 'bigserial'
        when 'int2'::regtype then 'smallserial' end as column_type,
        pg_get_serial_sequence(col.attrelid::regclass::text, col.attname) as sequence_name
from pg_catalog.pg_class t
    join pg_catalog.pg_namespace nsp on nsp.oid = t.relnamespace
    join pg_catalog.pg_attribute col on col.attrelid = t.oid
    join pg_catalog.pg_attrdef ad on ad.adrelid = col.attrelid and ad.adnum = col.attnum
    join pg_catalog.pg_constraint c on  c.conrelid = col.attrelid and col.attnum = any(c.conkey)
where
    col.atttypid = any('{int,int8,int2}'::regtype[])
    and not col.attisdropped
    and c.contype = 'p' -- primary keys
    and pg_get_expr(ad.adbin, ad.adrelid) = 'nextval(''' || pg_get_serial_sequence(col.attrelid::regclass::text, col.attname)::regclass || '''::regclass)'
    and nsp.nspname = :schema_name_param::text
order by t.oid::regclass::text, col.attname::text;
