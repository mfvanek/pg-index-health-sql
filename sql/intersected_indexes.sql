/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds indexes with overlapping sets of columns.
-- For example, (A) and (A+B) and (A+B+C).
-- Some of these indexes can usually be safely deleted.
-- noqa: disable=ST09,ST05,RF02
with
    index_info as (
        select
            pi.indrelid,
            pi.indexrelid,
            pi.indexrelid::regclass::text as index_name,
            /* definitions of index columns in index order: a column name or an expression text */
            /* (expression columns are stored in indkey as 0, so indkey alone cannot be compared) */
            array(
                select pg_get_indexdef(pi.indexrelid, k.pos, true)
                from generate_series(1, pi.indnatts) k(pos)
                order by k.pos
            ) as cols,
            'idx=' || pi.indexrelid::regclass || ', size=' || pg_relation_size(pi.indexrelid) as info,
            coalesce(pg_get_expr(pi.indpred, pi.indrelid, true), '') as pred
        from
            pg_catalog.pg_index pi
            inner join pg_catalog.pg_class pc on pc.oid = pi.indexrelid
            inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
        where
            nsp.nspname = :schema_name_param::text and
            not pc.relispartition
    )

select
    a.indrelid::regclass::text as table_name,
    a.info || '; ' || b.info as intersected_indexes
from
    (select * from index_info) a
    inner join
        (select * from index_info) b on (a.indrelid = b.indrelid and a.index_name < b.index_name and (
        /* the columns of one index are a leading prefix of the columns of the other */
        a.cols[1:cardinality(b.cols)] = b.cols or
        b.cols[1:cardinality(a.cols)] = a.cols
    ) and
    a.cols != b.cols and /* indexes with the same columns are reported by the duplicated_indexes check */
    a.pred = b.pred)
order by table_name, intersected_indexes;
