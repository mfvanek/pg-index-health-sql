/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds B-tree indexes on array columns
--
-- GIN-index should be used instead for such columns
-- Based on query from https://habr.com/ru/articles/800121/
select
    i.indrelid::regclass as table_name,  -- Name of the table
    i.indexrelid::regclass as index_name, -- Name of the index
    pg_relation_size(i.indexrelid) as index_size, -- Size of the index
    col.attname as column_name, -- Column name
    col.attnotnull as column_not_null -- Column not null
from pg_catalog.pg_index as i
    inner join pg_catalog.pg_class as ic on i.indexrelid = ic.oid
    inner join pg_catalog.pg_namespace as nsp on nsp.oid = ic.relnamespace
    inner join pg_catalog.pg_am as a on ic.relam = a.oid and a.amname = 'btree'
    inner join pg_catalog.pg_attribute as col on i.indrelid = col.attrelid and col.attnum = any((string_to_array(i.indkey::text, ' ')::int2[])[:i.indnkeyatts])
    inner join pg_catalog.pg_type as typ on typ.oid = col.atttypid
where
	nsp.nspname = :schema_name_param::text and
	typ.typcategory = 'A' -- A stands for Array type. See - https://www.postgresql.org/docs/current/catalog-pg-type.html#CATALOG-TYPCATEGORY-TABLE
order by ic.oid::regclass::text, i.indexrelid::regclass::text;
