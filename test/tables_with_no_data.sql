/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Test cases for tables_with_no_data.sql
-- Creates various table configurations and verifies which ones the query detects as empty.
-- Requires PostgreSQL 14+ and a live database connection.
-- Run ANALYZE after inserting data so pg_class statistics reflect actual page counts.

-- ============================================================
-- Setup
-- ============================================================

create schema if not exists test_no_data;

-- ── Regular tables ───────────────────────────────────────────

-- EXPECTED: appears — no data, relpages = 0
create table test_no_data.regular_empty (
    id bigint primary key,
    val text
);

-- EXPECTED: does not appear — has data
create table test_no_data.regular_with_data (
    id bigint primary key,
    val text
);

insert into test_no_data.regular_with_data (id, val) values (1, 'hello');

-- EXPECTED: does not appear — relpages stays > 0 after delete until vacuum frees the pages
create table test_no_data.regular_deleted_no_vacuum (
    id bigint primary key,
    val text
);

insert into test_no_data.regular_deleted_no_vacuum (id, val) values (1, 'to be deleted');
analyze test_no_data.regular_deleted_no_vacuum;
delete from test_no_data.regular_deleted_no_vacuum;

-- ── Single-level partitioned tables ──────────────────────────

-- EXPECTED: appears — no partitions at all; pg_partition_tree returns no leaf nodes,
-- the left join gives null, and coalesce falls back to the parent relpages = 0
create table test_no_data.partitioned_no_parts (
    id bigint,
    val text
) partition by range (id);

-- EXPECTED: appears — both leaf partitions are empty
create table test_no_data.partitioned_empty_parts (
    id bigint,
    val text
) partition by range (id);

create table test_no_data.partitioned_empty_parts_p1 partition of test_no_data.partitioned_empty_parts for values from (1) to (100);
create table test_no_data.partitioned_empty_parts_p2 partition of test_no_data.partitioned_empty_parts for values from (100) to (200);

-- EXPECTED: does not appear — p1 has data, sum(relpages) > 0 after analyze
create table test_no_data.partitioned_with_data (
    id bigint,
    val text
) partition by range (id);

create table test_no_data.partitioned_with_data_p1 partition of test_no_data.partitioned_with_data for values from (1) to (100);
create table test_no_data.partitioned_with_data_p2 partition of test_no_data.partitioned_with_data for values from (100) to (200);

insert into test_no_data.partitioned_with_data (id, val) values (50, 'hello');

-- ── Two-level partitioned tables (sub-partitioning) ──────────

-- EXPECTED: appears — all leaf partitions are empty
create table test_no_data.two_level_empty (
    id bigint,
    region text,
    val text
) partition by range (id);

create table test_no_data.two_level_empty_2020 partition of test_no_data.two_level_empty for values from (1) to (1000) partition by list (region);
create table test_no_data.two_level_empty_2020_us partition of test_no_data.two_level_empty_2020 for values in ('us');
create table test_no_data.two_level_empty_2020_eu partition of test_no_data.two_level_empty_2020 for values in ('eu');

-- EXPECTED: does not appear — the _us leaf partition has data after analyze
create table test_no_data.two_level_with_data (
    id bigint,
    region text,
    val text
) partition by range (id);

create table test_no_data.two_level_with_data_2020 partition of test_no_data.two_level_with_data for values from (1) to (1000) partition by list (region);
create table test_no_data.two_level_with_data_2020_us partition of test_no_data.two_level_with_data_2020 for values in ('us');
create table test_no_data.two_level_with_data_2020_eu partition of test_no_data.two_level_with_data_2020 for values in ('eu');

insert into test_no_data.two_level_with_data (id, region, val) values (50, 'us', 'hello');

-- ── Schema isolation ─────────────────────────────────────────

-- EXPECTED: does not appear when querying schema test_no_data
create schema if not exists test_no_data_other;

create table test_no_data_other.should_not_appear (
    id bigint primary key
);

-- ============================================================
-- Update statistics
-- ============================================================

analyze test_no_data.regular_with_data;
analyze test_no_data.partitioned_with_data_p1;
analyze test_no_data.partitioned_with_data_p2;
analyze test_no_data.two_level_with_data_2020_us;
analyze test_no_data.two_level_with_data_2020_eu;

-- ============================================================
-- Expected result when querying schema 'test_no_data' (4 rows):
--   test_no_data.partitioned_empty_parts | 0
--   test_no_data.partitioned_no_parts    | 0
--   test_no_data.regular_empty           | 0
--   test_no_data.two_level_empty         | 0
-- ============================================================

-- ============================================================
-- Cleanup
-- ============================================================

drop schema test_no_data cascade;
drop schema test_no_data_other cascade;
