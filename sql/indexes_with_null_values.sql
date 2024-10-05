/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds indexes that can contain null values.
select
    x.indrelid::regclass::text as table_name,
    x.indexrelid::regclass::text as index_name,
    string_agg(a.attname, ', ') as nullable_fields, -- In fact, there will always be only one column.
    pg_relation_size(x.indexrelid) as index_size
from
    pg_catalog.pg_index x
    inner join pg_catalog.pg_stat_all_indexes psai on psai.indexrelid = x.indexrelid
    inner join pg_catalog.pg_attribute a on a.attrelid = x.indrelid and a.attnum = any(x.indkey)
where
    not x.indisunique and
    not a.attnotnull and
    psai.schemaname = :schema_name_param::text and
    array_position(x.indkey, a.attnum) = 0 and /* only for first segment */
    (x.indpred is null or (position(lower(a.attname) in lower(pg_get_expr(x.indpred, x.indrelid))) = 0))
group by x.indrelid, x.indexrelid, x.indpred
order by table_name, index_name;
