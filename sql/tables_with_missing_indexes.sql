/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds tables that may not have enough indexes.
-- It is important to understand that this check will give a false positive result for small tables.
-- This sql query have to be executed on all hosts in the cluster.
-- The final result can be obtained as a union of results from all hosts.
-- Child partitions are intentionally not excluded: scans are counted per partition,
-- and partitioned (parent) tables always have zero scans, so they are never reported.
-- Summing scans up to the parent table would hide a single partition that is scanned sequentially.
with
    table_scans as (
        select
            psat.relid::regclass::text as table_name,
            pg_table_size(psat.relid) as table_size,
            coalesce(psat.seq_scan, 0) - coalesce(psat.idx_scan, 0) as too_much_seq,
            coalesce(psat.seq_scan, 0) as seq_scan,
            coalesce(psat.idx_scan, 0) as idx_scan
        from pg_catalog.pg_stat_all_tables psat
        where psat.schemaname = :schema_name_param::text
    )

select
    table_name,
    table_size,
    seq_scan,
    idx_scan
from table_scans
where
    (seq_scan + idx_scan) > 100::integer and /*table in use*/
    too_much_seq > 0 /*too much sequential scans*/
order by table_name;
