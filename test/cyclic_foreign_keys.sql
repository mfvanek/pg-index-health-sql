/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Test cases for sql/cyclic_foreign_keys.sql
--
-- Each test case lives in its own schema. Run the query once per schema and compare with the expected result:
--   psql -v schema_name_param="'tc02_two_tables'" -f sql/cyclic_foreign_keys.sql
--
-- The script can be executed repeatedly: every schema is dropped and created again.
-- The schemas must not be in the search_path, otherwise the table names are returned without the schema prefix.

---------------------------------------------------------------------------------------------------
-- Regular tables
---------------------------------------------------------------------------------------------------

-- tc01: no cycles. A chain of foreign keys and a self-referenced foreign key must not be reported.
-- Expected: 0 rows
drop schema if exists tc01_no_cycles cascade;
create schema tc01_no_cycles;

create table tc01_no_cycles.a (
    id bigint primary key,
    parent_id bigint,
    constraint a_parent_fk foreign key (parent_id) references tc01_no_cycles.a (id)
);

create table tc01_no_cycles.b (
    id bigint primary key,
    a_id bigint not null,
    constraint b_a_fk foreign key (a_id) references tc01_no_cycles.a (id)
);

create table tc01_no_cycles.c (
    id bigint primary key,
    b_id bigint not null,
    constraint c_b_fk foreign key (b_id) references tc01_no_cycles.b (id)
);

-- tc02: two tables reference each other. A deferrable foreign key on a nullable column is still a part of the cycle.
-- Expected: 1 row
--   table_names      = {tc02_two_tables.customers,tc02_two_tables.orders}
--   constraint_names = {customers_last_order_fk,orders_customer_fk}
--   columns          = {"last_order_id,false","customer_id,true"}
drop schema if exists tc02_two_tables cascade;
create schema tc02_two_tables;

create table tc02_two_tables.customers (
    id bigint primary key,
    last_order_id bigint
);

create table tc02_two_tables.orders (
    id bigint primary key,
    customer_id bigint not null,
    constraint orders_customer_fk foreign key (customer_id) references tc02_two_tables.customers (id)
);

alter table tc02_two_tables.customers
    add constraint customers_last_order_fk foreign key (last_order_id) references tc02_two_tables.orders (id) deferrable initially deferred;

-- tc03: a cycle of three tables. Table d references the cycle but is not a part of it.
-- The self-referenced foreign key on table b is ignored. The cycle is reported once, starting from table a.
-- Expected: 1 row
--   table_names      = {tc03_three_tables.a,tc03_three_tables.b,tc03_three_tables.c}
--   constraint_names = {a_b_fk,b_c_fk,c_a_fk}
--   columns          = {"b_id,true","c_id,true","a_id,true"}
drop schema if exists tc03_three_tables cascade;
create schema tc03_three_tables;

create table tc03_three_tables.a (
    id bigint primary key,
    b_id bigint not null
);

create table tc03_three_tables.b (
    id bigint primary key,
    c_id bigint not null,
    parent_id bigint,
    constraint b_parent_fk foreign key (parent_id) references tc03_three_tables.b (id)
);

create table tc03_three_tables.c (
    id bigint primary key,
    a_id bigint not null,
    constraint c_a_fk foreign key (a_id) references tc03_three_tables.a (id)
);

create table tc03_three_tables.d (
    id bigint primary key,
    a_id bigint not null,
    constraint d_a_fk foreign key (a_id) references tc03_three_tables.a (id)
);

alter table tc03_three_tables.a
    add constraint a_b_fk foreign key (b_id) references tc03_three_tables.b (id);

alter table tc03_three_tables.b
    add constraint b_c_fk foreign key (c_id) references tc03_three_tables.c (id);

-- tc04: two parallel foreign keys between the same tables produce two separate cycles.
-- Expected: 2 rows
--   table_names      = {tc04_parallel_keys.a,tc04_parallel_keys.b}
--   constraint_names = {a_b_first_fk,b_a_fk}
--   columns          = {"first_b_id,true","a_id,true"}
--
--   table_names      = {tc04_parallel_keys.a,tc04_parallel_keys.b}
--   constraint_names = {a_b_second_fk,b_a_fk}
--   columns          = {"second_b_id,false","a_id,true"}
drop schema if exists tc04_parallel_keys cascade;
create schema tc04_parallel_keys;

create table tc04_parallel_keys.a (
    id bigint primary key,
    first_b_id bigint not null,
    second_b_id bigint
);

create table tc04_parallel_keys.b (
    id bigint primary key,
    a_id bigint not null,
    constraint b_a_fk foreign key (a_id) references tc04_parallel_keys.a (id)
);

alter table tc04_parallel_keys.a
    add constraint a_b_first_fk foreign key (first_b_id) references tc04_parallel_keys.b (id);

alter table tc04_parallel_keys.a
    add constraint a_b_second_fk foreign key (second_b_id) references tc04_parallel_keys.b (id);

-- tc05: overlapping cycles a -> c -> a and a -> c -> b -> a share the foreign key a_c_fk. Each cycle is reported separately.
-- Expected: 2 rows
--   table_names      = {tc05_overlapping_cycles.a,tc05_overlapping_cycles.c}
--   constraint_names = {a_c_fk,c_a_fk}
--   columns          = {"c_id,true","a_id,true"}
--
--   table_names      = {tc05_overlapping_cycles.a,tc05_overlapping_cycles.c,tc05_overlapping_cycles.b}
--   constraint_names = {a_c_fk,c_b_fk,b_a_fk}
--   columns          = {"c_id,true","b_id,true","a_id,true"}
drop schema if exists tc05_overlapping_cycles cascade;
create schema tc05_overlapping_cycles;

create table tc05_overlapping_cycles.a (
    id bigint primary key,
    c_id bigint not null
);

create table tc05_overlapping_cycles.b (
    id bigint primary key,
    a_id bigint not null,
    constraint b_a_fk foreign key (a_id) references tc05_overlapping_cycles.a (id)
);

create table tc05_overlapping_cycles.c (
    id bigint primary key,
    a_id bigint not null,
    b_id bigint not null,
    constraint c_a_fk foreign key (a_id) references tc05_overlapping_cycles.a (id),
    constraint c_b_fk foreign key (b_id) references tc05_overlapping_cycles.b (id)
);

alter table tc05_overlapping_cycles.a
    add constraint a_c_fk foreign key (c_id) references tc05_overlapping_cycles.c (id);

-- tc06: a multicolumn foreign key takes one position per column and keeps the column order of the constraint
-- (customer_id, region_id), which differs from the column order in the table.
-- Expected: 1 row
--   table_names      = {tc06_multicolumn_key.customers,tc06_multicolumn_key.orders,tc06_multicolumn_key.orders}
--   constraint_names = {customers_last_order_fk,orders_customer_fk,orders_customer_fk}
--   columns          = {"last_order_id,false","customer_id,true","region_id,true"}
drop schema if exists tc06_multicolumn_key cascade;
create schema tc06_multicolumn_key;

create table tc06_multicolumn_key.customers (
    id bigint primary key,
    region_id bigint not null,
    last_order_id bigint,
    constraint customers_id_region_uq unique (id, region_id)
);

create table tc06_multicolumn_key.orders (
    id bigint primary key,
    region_id bigint not null,
    customer_id bigint not null,
    constraint orders_customer_fk foreign key (customer_id, region_id) references tc06_multicolumn_key.customers (id, region_id)
);

alter table tc06_multicolumn_key.customers
    add constraint customers_last_order_fk foreign key (last_order_id) references tc06_multicolumn_key.orders (id);

-- tc07: a cycle that passes through another schema is not reported for either schema.
-- Expected: 0 rows for tc07_first_schema and 0 rows for tc07_second_schema
drop schema if exists tc07_first_schema cascade;
drop schema if exists tc07_second_schema cascade;
create schema tc07_first_schema;
create schema tc07_second_schema;

create table tc07_first_schema.a (
    id bigint primary key,
    b_id bigint not null
);

create table tc07_second_schema.b (
    id bigint primary key,
    a_id bigint not null,
    constraint b_a_fk foreign key (a_id) references tc07_first_schema.a (id)
);

alter table tc07_first_schema.a
    add constraint a_b_fk foreign key (b_id) references tc07_second_schema.b (id);

---------------------------------------------------------------------------------------------------
-- Partitioned tables
---------------------------------------------------------------------------------------------------

-- tc08: no cycles. Foreign keys from and to a partitioned table are cloned for every partition,
-- these clones must not be reported and must not produce false cycles.
-- Expected: 0 rows
drop schema if exists tc08_partitioned_no_cycles cascade;
create schema tc08_partitioned_no_cycles;

create table tc08_partitioned_no_cycles.a (
    id bigint primary key
);

create table tc08_partitioned_no_cycles.p (
    id bigint primary key,
    a_id bigint not null,
    constraint p_a_fk foreign key (a_id) references tc08_partitioned_no_cycles.a (id)
) partition by range (id);

create table tc08_partitioned_no_cycles.p_1 partition of tc08_partitioned_no_cycles.p for values from (1) to (100);
create table tc08_partitioned_no_cycles.p_2 partition of tc08_partitioned_no_cycles.p for values from (100) to (200);

create table tc08_partitioned_no_cycles.b (
    id bigint primary key,
    p_id bigint not null,
    constraint b_p_fk foreign key (p_id) references tc08_partitioned_no_cycles.p (id)
);

-- tc09: a partitioned table and a regular table reference each other.
-- The cycle is reported once in terms of the partitioned table, partitions are not mentioned.
-- Expected: 1 row
--   table_names      = {tc09_partitioned_and_regular.p,tc09_partitioned_and_regular.q}
--   constraint_names = {p_q_fk,q_p_fk}
--   columns          = {"q_id,false","p_id,true"}
drop schema if exists tc09_partitioned_and_regular cascade;
create schema tc09_partitioned_and_regular;

create table tc09_partitioned_and_regular.p (
    id bigint primary key,
    q_id bigint
) partition by range (id);

create table tc09_partitioned_and_regular.p_1 partition of tc09_partitioned_and_regular.p for values from (1) to (100);
create table tc09_partitioned_and_regular.p_2 partition of tc09_partitioned_and_regular.p for values from (100) to (200);

create table tc09_partitioned_and_regular.q (
    id bigint primary key,
    p_id bigint not null,
    constraint q_p_fk foreign key (p_id) references tc09_partitioned_and_regular.p (id)
);

alter table tc09_partitioned_and_regular.p
    add constraint p_q_fk foreign key (q_id) references tc09_partitioned_and_regular.q (id);

-- tc10: two partitioned tables reference each other.
-- Expected: 1 row
--   table_names      = {tc10_partitioned_both.p,tc10_partitioned_both.q}
--   constraint_names = {p_q_fk,q_p_fk}
--   columns          = {"q_id,true","p_id,true"}
drop schema if exists tc10_partitioned_both cascade;
create schema tc10_partitioned_both;

create table tc10_partitioned_both.p (
    id bigint primary key,
    q_id bigint not null
) partition by range (id);

create table tc10_partitioned_both.p_1 partition of tc10_partitioned_both.p for values from (1) to (100);
create table tc10_partitioned_both.p_2 partition of tc10_partitioned_both.p for values from (100) to (200);

create table tc10_partitioned_both.q (
    id bigint primary key,
    p_id bigint not null,
    constraint q_p_fk foreign key (p_id) references tc10_partitioned_both.p (id)
) partition by hash (id);

create table tc10_partitioned_both.q_1 partition of tc10_partitioned_both.q for values with (modulus 2, remainder 0);
create table tc10_partitioned_both.q_2 partition of tc10_partitioned_both.q for values with (modulus 2, remainder 1);

alter table tc10_partitioned_both.p
    add constraint p_q_fk foreign key (q_id) references tc10_partitioned_both.q (id);

-- tc11: foreign keys declared directly on a partition or referencing a partition directly are ignored.
-- Partition p_1 and table q reference each other, but the parent table p has no foreign keys at all.
-- Expected: 0 rows
drop schema if exists tc11_partition_level_keys cascade;
create schema tc11_partition_level_keys;

create table tc11_partition_level_keys.p (
    id bigint primary key,
    q_id bigint not null
) partition by range (id);

create table tc11_partition_level_keys.p_1 partition of tc11_partition_level_keys.p for values from (1) to (100);
create table tc11_partition_level_keys.p_2 partition of tc11_partition_level_keys.p for values from (100) to (200);

create table tc11_partition_level_keys.q (
    id bigint primary key,
    p_id bigint not null,
    constraint q_p_1_fk foreign key (p_id) references tc11_partition_level_keys.p_1 (id)
);

alter table tc11_partition_level_keys.p_1
    add constraint p_1_q_fk foreign key (q_id) references tc11_partition_level_keys.q (id);
