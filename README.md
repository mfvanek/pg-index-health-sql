# pg-index-health-sql
**pg-index-health-sql** is a set of sql-queries for analyzing and maintaining indexes health in Postgresql databases.

[![Lint Code Base](https://github.com/mfvanek/pg-index-health-sql/actions/workflows/linter.yml/badge.svg)](https://github.com/mfvanek/pg-index-health-sql/actions/workflows/linter.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://github.com/mfvanek/pg-index-health-sql/blob/master/LICENSE "Apache License 2.0")

## Supported PostgreSQL versions
[![PostgreSQL 9.6](https://img.shields.io/badge/PostgreSQL-9.6-green.svg)](https://www.postgresql.org/about/news/1703/ "PostgreSQL 9.6")
[![PostgreSQL 10](https://img.shields.io/badge/PostgreSQL-10-green.svg)](https://www.postgresql.org/about/news/1786/ "PostgreSQL 10")
[![PostgreSQL 11](https://img.shields.io/badge/PostgreSQL-11-green.svg)](https://www.postgresql.org/about/news/1894/ "PostgreSQL 11")
[![PostgreSQL 12](https://img.shields.io/badge/PostgreSQL-12-green.svg)](https://www.postgresql.org/about/news/1976/ "PostgreSQL 12")
[![PostgreSQL 13](https://img.shields.io/badge/PostgreSQL-13-green.svg)](https://www.postgresql.org/about/news/postgresql-13-released-2077/ "PostgreSQL 13")
[![PostgreSQL 14](https://img.shields.io/badge/PostgreSQL-14-green.svg)](https://www.postgresql.org/about/news/postgresql-14-released-2318/ "PostgreSQL 14")

## Available checks
**pg-index-health-sql** allows you to detect the following problems:
1. Invalid (broken) indexes ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/invalid_indexes.sql)).
2. Duplicated (completely identical) indexes ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/duplicated_indexes.sql)).
3. Intersected (partially identical) indexes ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/intersected_indexes.sql)).
4. Unused indexes ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/unused_indexes.sql)).
5. Foreign keys without associated indexes ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/foreign_keys_without_index.sql)).
6. Indexes with null values ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/indexes_with_null_values.sql)).
7. Tables with missing indexes ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/tables_with_missing_indexes.sql)).
8. Tables without primary key ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/tables_without_primary_key.sql)).
9. Indexes [bloat](https://www.percona.com/blog/2018/08/06/basic-understanding-bloat-vacuum-postgresql-mvcc/) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/bloated_indexes.sql)).
10. Tables [bloat](https://www.percona.com/blog/2018/08/06/basic-understanding-bloat-vacuum-postgresql-mvcc/) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/bloated_tables.sql)).
11. Tables without [description](https://www.postgresql.org/docs/current/sql-comment.html) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/tables_without_description.sql)).
12. Columns without [description](https://www.postgresql.org/docs/current/sql-comment.html) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/columns_without_description.sql)).
13. Columns with [json](https://www.postgresql.org/docs/current/datatype-json.html) type ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/columns_with_json_type.sql)).
14. Columns of [serial types](https://www.postgresql.org/docs/current/datatype-numeric.html#DATATYPE-SERIAL) that not are primary keys ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/non_primary_key_columns_with_serial_types.sql)).
