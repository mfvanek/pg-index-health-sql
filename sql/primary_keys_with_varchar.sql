/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds primary keys with columns of varchar(32/36/38) type.
-- Usually this columns should use built-in uuid type.
--
-- See https://www.postgresql.org/docs/17/datatype-uuid.html
-- b9b1f6f5-7f90-4b68-a389-f0ad8bb5784b - with dashes - 36 characters
-- b9b1f6f57f904b68a389f0ad8bb5784b - without dashes - 32 characters
-- {b9b1f6f5-7f90-4b68-a389-f0ad8bb5784b} - with curly braces - 38 characters
select
    pc.oid::regclass::text as table_name,
    i.indexrelid::regclass as index_name,
    array_agg(quote_ident(a.attname) || ',' || a.attnotnull::text order by a.attnum) as columns
from
    pg_catalog.pg_class pc
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
    inner join pg_catalog.pg_index i on i.indrelid = pc.oid
    inner join pg_catalog.pg_attribute a on a.attrelid = pc.oid and a.attnum = any(i.indkey)
where
    not a.attisdropped and
    a.attnum > 0 and
    not pc.relispartition and
    pc.relkind in ('r', 'p') and /* regular and partitioned tables */
    i.indisprimary and
    exists (
        select 1
        from
            pg_catalog.pg_attribute a2
        where
            a2.attrelid = pc.oid and
            a2.attnum = any(i.indkey) and
            not a2.attisdropped and
            a2.attnum > 0 and
            a2.atttypid = any('{varchar,bpchar}'::regtype[]) and
            (a2.atttypmod - 4) in (32, 36, 38)
    ) and
    nsp.nspname = :schema_name_param::text
group by pc.oid, i.indexrelid
order by table_name, index_name;
