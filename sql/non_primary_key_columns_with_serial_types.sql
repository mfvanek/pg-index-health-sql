/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds columns of serial types (smallserial/serial/bigserial)
-- that are not primary keys (or primary and foreign keys at the same time).
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
    join pg_attrdef ad on ad.adrelid = col.attrelid and ad.adnum = col.attnum
    left join lateral (
        select sum(case when c.contype = 'p' then +1 else -1 end) as res
        from pg_constraint c
        where
            c.conrelid = col.attrelid and
            c.conkey[1] = col.attnum and
            c.contype in ('p', 'f') and /* primary or foreign key */
            array_length(c.conkey, 1) = 1 /* single column */
        group by c.conrelid, c.conkey[1]) c on true
where
    t.relkind = 'r' and
    col.attnum > 0 and /* to filter out system columns such as oid, ctid, xmin, xmax, etc. */
    not col.attisdropped and
    col.atttypid = any('{int,int8,int2}'::regtype[]) and
    (c.res is null or c.res <= 0) and
    /* column default value = nextval from owned sequence */
    pg_get_expr(ad.adbin, ad.adrelid) = 'nextval(''' || (pg_get_serial_sequence(col.attrelid::regclass::text, col.attname))::regclass || '''::regclass)' and
    nsp.nspname = :schema_name_param::text
order by t.oid::regclass::text, col.attname::text;
