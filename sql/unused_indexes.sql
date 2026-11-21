/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds potentially unused indexes.
-- This sql query have to be executed on all hosts in the cluster.
-- The final result can be obtained as an intersection of results from all hosts.
-- Indexes on partitions that are attached to a partitioned index cannot be dropped separately,
-- so they are counted together with their root index: scans and sizes are summed over all partitions.
-- noqa: disable=RF02
with
    nsp as (
        select
            nsp.oid,
            nsp.nspname
        from pg_catalog.pg_namespace nsp
        where
            nsp.nspname = :schema_name_param::text
    ),

    /* the same rules as in foreign_keys_without_index: an index serves a foreign key only if it can be used for the lookup by it */
    foreign_key_index_candidates as (
        select
            pi.indexrelid,
            pi.indrelid,
            c.conkey::int[] as fk_columns,
            pg_catalog.pg_get_expr(pi.indpred, pi.indrelid) as predicate
        from
            pg_catalog.pg_constraint c
            inner join nsp on nsp.oid = c.connamespace
            inner join pg_catalog.pg_index pi on pi.indrelid = c.conrelid
            inner join pg_catalog.pg_class pc on pc.oid = pi.indexrelid
            inner join pg_catalog.pg_am am on am.oid = pc.relam
        where
            c.contype = 'f' and
            am.amname != 'brin' and /* brin index does not speed up lookups by foreign key */
            (c.conkey::int[] <@ pi.indkey::int[]) and /* all columns of foreign key have to present in index */
            (pi.indkey::int[])[0] = any(c.conkey::int[]) /* index starts with any column of foreign key: for equality lookup the order of columns does not matter */
    ),

    foreign_key_indexes as (
        select fkic.indexrelid
        from foreign_key_index_candidates fkic
        where
            fkic.predicate is null or (
                /* a partial index serves a foreign key only if its predicate consists solely of "fk_column IS NOT NULL" conditions joined by AND */
                btrim(regexp_replace(regexp_replace(fkic.predicate, '\(("(?:[^"]|"")+"|[^()" ]+) IS NOT NULL\)', '', 'g'), '\s+AND\s+|[()\s]', '', 'g')) = '' and
                not exists (
                    select 1
                    from
                        regexp_matches(fkic.predicate, '\(("(?:[^"]|"")+"|[^()" ]+) IS NOT NULL\)', 'g') m(cols)
                        left join pg_catalog.pg_attribute col on col.attrelid = fkic.indrelid and quote_ident(col.attname) = m.cols[1]
                    where
                        col.attnum is null or /* the tested column is not resolved */
                        col.attnum != all(fkic.fk_columns) /* the tested column is not a part of the foreign key */
                )
            )
    ),

    index_usage as (
        select
            psui.indexrelid,
            psui.idx_scan,
            /* pg_partition_root() returns null for an index that is not a part of a partitioned index */
            coalesce(pg_partition_root(psui.indexrelid), psui.indexrelid) as root_indexrelid,
            psui.indexrelid in (select fki.indexrelid from foreign_key_indexes fki) as is_foreign_key_index
        from pg_catalog.pg_stat_user_indexes psui
    ),

    unused_indexes as (
        select
            pi.indrelid,
            pi.indexrelid,
            sum(iu.idx_scan)::bigint as index_scans
        from
            index_usage iu
            inner join pg_catalog.pg_index pi on pi.indexrelid = iu.root_indexrelid
            inner join pg_catalog.pg_class pc on pc.oid = pi.indexrelid
        where
            pc.relnamespace in (select nsp.oid from nsp) and
            pi.indisvalid and /* invalid indexes are reported by the invalid_indexes check */
            not pi.indisunique and
            not pi.indisexclusion /* indexes of exclusion constraints cannot be dropped separately */
        group by pi.indrelid, pi.indexrelid
        having
            not bool_or(iu.is_foreign_key_index) and /* retain indexes on foreign keys */
            sum(iu.idx_scan) < 50::integer
    )

/* sizes are calculated only for the found indexes: pg_relation_size() locks the index */
select
    ui.indrelid::regclass::text as table_name,
    ui.indexrelid::regclass::text as index_name,
    ui.index_scans,
    (
        select sum(pg_relation_size(iu.indexrelid))
        from index_usage iu
        where iu.root_indexrelid = ui.indexrelid
    )::bigint as index_size
from unused_indexes ui
order by table_name, index_name;
