# pg-index-health-sql
**pg-index-health-sql** is a set of sql-queries for analyzing and maintaining indexes health in Postgresql databases.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://github.com/mfvanek/pg-index-health-sql/blob/master/LICENSE)

## Supported PostgreSQL versions
[![PostgreSQL 9.6](https://img.shields.io/badge/PostgreSQL-9.6-green.svg)](https://www.postgresql.org/download/)
[![PostgreSQL 10](https://img.shields.io/badge/PostgreSQL-10-green.svg)](https://www.postgresql.org/download/)
[![PostgreSQL 11](https://img.shields.io/badge/PostgreSQL-11-green.svg)](https://www.postgresql.org/download/)
[![PostgreSQL 12](https://img.shields.io/badge/PostgreSQL-12-green.svg)](https://www.postgresql.org/download/)

## Available checks
**pg-index-health** allows you to detect the following problems:
1. Invalid (broken) indexes ([sql](https://github.com/mfvanek/pg-index-health/blob/master/src/main/resources/sql/invalid_indexes.sql)).
1. Duplicated (completely identical) indexes ([sql](https://github.com/mfvanek/pg-index-health/blob/master/src/main/resources/sql/duplicated_indexes.sql)).
1. Intersected (partially identical) indexes ([sql](https://github.com/mfvanek/pg-index-health/blob/master/src/main/resources/sql/intersected_indexes.sql)).
1. Unused indexes ([sql](https://github.com/mfvanek/pg-index-health/blob/master/src/main/resources/sql/unused_indexes.sql)).
1. Foreign keys without associated indexes ([sql](https://github.com/mfvanek/pg-index-health/blob/master/src/main/resources/sql/foreign_keys_without_index.sql)).
1. Indexes with null values ([sql](https://github.com/mfvanek/pg-index-health/blob/master/src/main/resources/sql/indexes_with_null_values.sql)).
1. Tables with missing indexes ([sql](https://github.com/mfvanek/pg-index-health/blob/master/src/main/resources/sql/tables_with_missing_indexes.sql)).
1. Tables without primary key ([sql](https://github.com/mfvanek/pg-index-health/blob/master/src/main/resources/sql/tables_without_primary_key.sql)).
1. Indexes bloat ([sql](https://github.com/mfvanek/pg-index-health/blob/master/src/main/resources/sql/bloated_indexes.sql)).
1. Tables bloat ([sql](https://github.com/mfvanek/pg-index-health/blob/master/src/main/resources/sql/bloated_tables.sql)).
