/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds tables that appear to be empty based on pg_catalog statistics.
-- For regular tables, uses relpages = 0 (no data pages allocated) as the signal.
-- For partitioned tables, aggregates relpages across all leaf partitions via pg_partition_tree(),
-- since the partitioned parent itself never stores data and always has relpages = 0.
-- Note: tables that had rows deleted but not yet vacuumed will still have relpages > 0 and won't appear here.
--
-- See also schemacrawler.tools.linter.LinterTableEmpty https://www.schemacrawler.com/lint.html
with
    tables_in_schema as (
        select
            pc.oid,
            pc.relkind,
            pc.relpages
        from
            pg_catalog.pg_class pc
            inner join pg_catalog.pg_namespace nsp on nsp.oid = pc.relnamespace
        where
            nsp.nspname = :schema_name_param::text and
            pc.relkind in ('r', 'p') and
            not pc.relispartition
    ),

    partition_pages as (
        select
            tis.oid as root_oid,
            sum(pc.relpages) as total_pages
        from
            tables_in_schema tis
            cross join lateral pg_catalog.pg_partition_tree(tis.oid) ppt
            inner join pg_catalog.pg_class pc on pc.oid = ppt.relid
        where
            tis.relkind = 'p' and
            ppt.isleaf
        group by tis.oid
    )

select
    tis.oid::regclass::text as table_name,
    pg_table_size(tis.oid) as table_size
from
    tables_in_schema tis
    left join partition_pages pp on pp.root_oid = tis.oid
where
    coalesce(pp.total_pages, tis.relpages) = 0
order by table_name;
