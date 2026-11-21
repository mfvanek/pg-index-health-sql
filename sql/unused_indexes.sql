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

    foreign_key_indexes as (
        select pi.indexrelid
        from
            pg_catalog.pg_constraint c
            inner join nsp on nsp.oid = c.connamespace
            inner join pg_catalog.pg_index pi on pi.indrelid = c.conrelid
            inner join pg_catalog.pg_class pc on pc.oid = pi.indexrelid
            inner join pg_catalog.pg_am am on am.oid = pc.relam
        where
            c.contype = 'f' and
            am.amname != 'brin' and /* brin index does not speed up lookups by foreign key (see foreign_keys_without_index) */
            (c.conkey::int[] <@ pi.indkey::int[]) and /* all columns of foreign key have to present in index */
            (pi.indkey::int[])[0] = any(c.conkey::int[]) /* index starts with any column of foreign key: for equality lookup the order of columns does not matter */
    ),

    index_usage as (
        select
            psui.idx_scan,
            /* pg_partition_root() returns null for an index that is not a part of a partitioned index */
            coalesce(pg_partition_root(psui.indexrelid), psui.indexrelid) as root_indexrelid,
            pg_relation_size(psui.indexrelid) as index_size,
            psui.indexrelid in (select fki.indexrelid from foreign_key_indexes fki) as is_foreign_key_index
        from pg_catalog.pg_stat_user_indexes psui
    )

select
    pi.indrelid::regclass::text as table_name,
    pi.indexrelid::regclass::text as index_name,
    sum(iu.idx_scan)::bigint as index_scans,
    sum(iu.index_size)::bigint as index_size
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
order by table_name, index_name;
