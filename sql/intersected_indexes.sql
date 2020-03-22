/*
 * Copyright (c) 2019-2020. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds indexes with overlapping sets of columns.
-- For example, (A) and (A+B) and (A+B+C).
-- Some of these indexes can usually be safely deleted.
with index_info as (
    select
         pi.indrelid,
         pi.indexrelid,
         array_to_string(pi.indkey, ' ') as cols,
         'idx=' || pi.indexrelid::regclass || ', size=' || pg_relation_size(pi.indexrelid) as info,
         coalesce(pg_get_expr(pi.indpred, pi.indrelid, true), '') as pred
    from pg_catalog.pg_index pi
        join pg_catalog.pg_stat_all_indexes psai on pi.indexrelid = psai.indexrelid
    where psai.schemaname = :schema_name_param::text
)
select
    a.indrelid::regclass as table_name,
    a.info || '; ' || b.info as intersected_indexes
from
    (select * from index_info) as a
       join
    (select * from index_info) as b
        on (a.indrelid = b.indrelid and a.indexrelid > b.indexrelid and (
           (a.cols like b.cols || '%' and coalesce(substr(a.cols, length(b.cols) + 1, 1), ' ') = ' ') or
           (b.cols like a.cols || '%' and coalesce(substr(b.cols, length(a.cols) + 1, 1), ' ') = ' ')) and
            a.pred = b.pred)
order by a.indrelid::regclass::text;
