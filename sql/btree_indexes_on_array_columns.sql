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

    a.amname    -- index type
from pg_catalog.pg_index as i
    inner join pg_catalog.pg_stat_all_indexes psai on i.indexrelid = psai.indexrelid
    inner join pg_catalog.pg_class as ic on i.indexrelid = ic.oid
    inner join pg_catalog.pg_am as a on ic.relam = a.oid and a.amname = 'btree'
    inner join pg_catalog.pg_class as c on i.indrelid = c.oid
where psai.schemaname = :schemaname and
-- check the existence of a column with an array type in the index
    exists (select * from pg_catalog.pg_attribute as att
                inner join pg_catalog.pg_type as typ on typ.oid = att.atttypid
                where att.attrelid = i.indrelid
                    and att.attnum = any ((string_to_array(indkey::text, ' ')::int2[])[1:indnkeyatts])
                    and typ.typcategory = 'A');