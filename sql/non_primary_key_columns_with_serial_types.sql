/*
 * Copyright (c) 2019-2022. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds columns of serial types (smallserial/serial/bigserial) that not are primary keys.
-- Based on https://dba.stackexchange.com/questions/90555/postgresql-select-primary-key-as-serial-or-bigserial/
select
    col.attrelid::regclass::text as table_name,
    col.attname::text as column_name,
    col.attnotnull as column_not_null,
    case col.atttypid
        when 'int'::regtype then 'serial'
        when 'int8'::regtype then 'bigserial'
        when 'int2'::regtype then 'smallserial' end as column_type,
    pg_get_serial_sequence(col.attrelid::regclass::text, col.attname) as sequence_name
from
    pg_catalog.pg_class t
    join pg_catalog.pg_namespace nsp on nsp.oid = t.relnamespace
    join pg_catalog.pg_attribute col on col.attrelid = t.oid
    join pg_constraint c on c.conrelid = col.attrelid and c.conkey[1] = col.attnum
    join pg_attrdef ad on ad.adrelid = col.attrelid and ad.adnum = col.attnum
where
    t.relkind = 'r' and
    col.attnum > 0 and /* to filter out system columns such as oid, ctid, xmin, xmax, etc. */
    not col.attisdropped and
    col.atttypid = any('{int,int8,int2}'::regtype[]) and
    c.contype != 'p' and /* not primary key */
    array_length(c.conkey, 1) = 1 and /* single column */
    /* column default value = nextval from owned sequence */
    pg_get_expr(ad.adbin, ad.adrelid) = 'nextval(''' || (pg_get_serial_sequence(col.attrelid::regclass::text, col.attname))::regclass || '''::regclass)' and
    nsp.nspname = :schema_name_param::text
order by t.oid::regclass::text, col.attname::text;
