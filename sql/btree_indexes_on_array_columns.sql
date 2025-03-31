/*
 * Copyright (c) 2019-2025. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds B-tree indexes on array columns
--
-- GIN-index should be used instead for such columns
-- Based on query from https://habr.com/ru/articles/800121/
-- See also https://www.postgresql.org/docs/current/catalog-pg-type.html#CATALOG-TYPCATEGORY-TABLE
select
    i.indrelid::regclass::text as table_name,
    i.indexrelid::regclass::text as index_name,
    col.attname::text as column_name,
    col.attnotnull as column_not_null,
    pg_relation_size(i.indexrelid) as index_size
from pg_catalog.pg_index i
    inner join pg_catalog.pg_class ic on ic.oid = i.indexrelid
    inner join pg_catalog.pg_namespace nsp on nsp.oid = ic.relnamespace
    inner join pg_catalog.pg_am am on am.oid = ic.relam and am.amname = 'btree'
    inner join pg_catalog.pg_attribute col on col.attrelid = i.indrelid and col.attnum = any((string_to_array(i.indkey::text, ' ')::int2[])[:i.indnkeyatts])
    inner join pg_catalog.pg_type typ on typ.oid = col.atttypid
where
    nsp.nspname = :schema_name_param::text and
    not ic.relispartition and
    typ.typcategory = 'A' /* A stands for Array type */
order by table_name, index_name;
