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
--
-- Returns all columns of such an index in their original order.
-- Each column is returned as "name,not_null,type", so array columns can be identified by the type.
-- Expressions are not included in the columns: they have no column name (they are stored in indkey as 0).
select
    pi.indrelid::regclass::text as table_name,
    pi.indexrelid::regclass::text as index_name,
    pg_relation_size(pi.indexrelid) as index_size,
    array_agg(quote_ident(col.attname) || ',' || col.attnotnull::text || ',' || col.atttypid::regtype::text order by u.attposition) as columns
from
    pg_catalog.pg_index pi
    inner join pg_catalog.pg_class pc on pc.oid = pi.indexrelid
    inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
    inner join pg_catalog.pg_am am on am.oid = pc.relam and am.amname = 'btree'
    inner join unnest(pi.indkey) with ordinality u(attnum, attposition) on true
    inner join pg_catalog.pg_attribute col on col.attrelid = pi.indrelid and col.attnum = u.attnum /* skips expressions (attnum 0) */
where
    nsp.nspname = :schema_name_param::text and
    not pc.relispartition and
    exists (
        select 1
        from
            pg_catalog.pg_attribute arr_col
            inner join pg_catalog.pg_type typ on typ.oid = arr_col.atttypid
        where
            arr_col.attrelid = pi.indrelid and
            /* only key columns: columns from the include clause (positions from indnkeyatts on) are not used for searching */
            arr_col.attnum = any((pi.indkey::int2[])[0:pi.indnkeyatts - 1]) and
            typ.typcategory = 'A' /* A stands for Array type */
    )
group by pi.indrelid, pi.indexrelid
order by table_name, index_name;
