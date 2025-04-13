/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
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
with
    nsp as (
        select nsp.oid
        from pg_catalog.pg_namespace nsp
        where
            nsp.nspname = :schema_name_param::text
    ),

    t as (
        select
            col.attrelid::regclass::text as table_name,
            col.attnotnull as column_not_null,
            s.seqrelid::regclass::text as sequence_name,
            quote_ident(col.attname::text) as column_name,
            case col.atttypid
                when 'int'::regtype then 'serial'
                when 'int8'::regtype then 'bigserial'
                when 'int2'::regtype then 'smallserial'
            end as column_type,
            pg_get_expr(ad.adbin, ad.adrelid) as column_default_value
        from
            pg_catalog.pg_class t
            inner join nsp on nsp.oid = t.relnamespace
            inner join pg_catalog.pg_attribute col on col.attrelid = t.oid
            inner join pg_catalog.pg_constraint c on c.conrelid = col.attrelid and col.attnum = any(c.conkey)
            inner join pg_catalog.pg_attrdef ad on ad.adrelid = col.attrelid and ad.adnum = col.attnum
            inner join pg_catalog.pg_depend dep on dep.refobjid = col.attrelid and dep.refobjsubid = col.attnum
            inner join pg_catalog.pg_sequence s on s.seqrelid = dep.objid
        where
            col.atttypid = any('{int,int8,int2}'::regtype[]) and
            not col.attisdropped and
            c.contype = 'p' and /* primary keys */
            dep.deptype = 'a' /* DEPENDENCY_AUTO */
    )

select
    table_name,
    column_name,
    column_not_null,
    column_type,
    sequence_name
from t
where
    column_default_value = 'nextval(''' || sequence_name || '''::regclass)'
order by table_name, column_name;
