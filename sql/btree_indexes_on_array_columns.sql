/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds B-tree indexes on array columns
--
-- GIN-index should be used instead for such columns
-- Based on a query from https://habr.com/ru/articles/800121/
-- See also https://www.postgresql.org/docs/current/catalog-pg-type.html#CATALOG-TYPCATEGORY-TABLE
select
    pi.indrelid::regclass::text as table_name,
    pi.indexrelid::regclass::text as index_name,
    col.attnotnull as column_not_null,
    quote_ident(col.attname) as column_name,
    pg_relation_size(pi.indexrelid) as index_size
from
    pg_catalog.pg_index pi
    inner join pg_catalog.pg_class pc on pc.oid = pi.indexrelid
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
    inner join pg_catalog.pg_am am on am.oid = pc.relam and am.amname = 'btree'
    inner join pg_catalog.pg_attribute col on col.attrelid = pi.indrelid and col.attnum = any((string_to_array(pi.indkey::text, ' ')::int2[])[:pi.indnkeyatts])
    inner join pg_catalog.pg_type typ on typ.oid = col.atttypid
where
    nsp.nspname = :schema_name_param::text and
    not pc.relispartition and
    typ.typcategory = 'A' /* A stands for Array type */
order by table_name, index_name;
