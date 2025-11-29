# pg-index-health-sql

**pg-index-health-sql** is a collection of SQL queries for analyzing PostgreSQL schemas, detecting issues and promoting best practices.

[![Lint Code Base](https://github.com/mfvanek/pg-index-health-sql/actions/workflows/linter.yml/badge.svg)](https://github.com/mfvanek/pg-index-health-sql/actions/workflows/linter.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://github.com/mfvanek/pg-index-health-sql/blob/master/LICENSE "Apache License 2.0")

## What is this?

**pg-index-health-sql** provides a curated set of raw SQL queries designed to identify common schema issues in PostgreSQL databases — such as redundant indexes, missing primary keys or inefficient table structures.

It enables lightweight, database-native analysis without requiring external libraries or frameworks, making it suitable for direct use in psql sessions, scripts, or monitoring dashboards.

## Supported PostgreSQL versions

[![PostgreSQL 14](https://img.shields.io/badge/PostgreSQL-14-green.svg)](https://www.postgresql.org/about/news/postgresql-14-released-2318/ "PostgreSQL 14")
[![PostgreSQL 15](https://img.shields.io/badge/PostgreSQL-15-green.svg)](https://www.postgresql.org/about/news/postgresql-15-released-2526/ "PostgreSQL 15")
[![PostgreSQL 16](https://img.shields.io/badge/PostgreSQL-16-green.svg)](https://www.postgresql.org/about/news/postgresql-16-released-2715/ "PostgreSQL 16")
[![PostgreSQL 17](https://img.shields.io/badge/PostgreSQL-17-green.svg)](https://www.postgresql.org/about/news/postgresql-17-released-2936/ "PostgreSQL 17")
[![PostgreSQL 18](https://img.shields.io/badge/PostgreSQL-18-green.svg)](https://www.postgresql.org/about/news/postgresql-18-released-3142/ "PostgreSQL 18")

### Support for previous versions of PostgreSQL

Compatibility with previous PostgreSQL versions is no longer guaranteed, but it is very likely.  
We focus only on the currently maintained versions of PostgreSQL.  
For more information please see [PostgreSQL Versioning Policy](https://www.postgresql.org/support/versioning/).

## Available checks

**pg-index-health-sql** allows you to detect the following problems:
1. Invalid (broken) indexes ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/invalid_indexes.sql)).
2. Duplicated (completely identical) indexes ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/duplicated_indexes.sql)).
3. Intersected (partially identical) indexes ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/intersected_indexes.sql)).
4. Unused indexes ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/unused_indexes.sql)).
5. Foreign keys without associated indexes ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/foreign_keys_without_index.sql)).
6. Indexes with null values ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/indexes_with_null_values.sql)).
7. Tables with missing indexes ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/tables_with_missing_indexes.sql)).
8. Tables without a primary key ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/tables_without_primary_key.sql)).
9. Indexes [bloat](https://www.percona.com/blog/2018/08/06/basic-understanding-bloat-vacuum-postgresql-mvcc/) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/bloated_indexes.sql)).
10. Tables [bloat](https://www.percona.com/blog/2018/08/06/basic-understanding-bloat-vacuum-postgresql-mvcc/) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/bloated_tables.sql)).
11. Tables without [description](https://www.postgresql.org/docs/current/sql-comment.html) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/tables_without_description.sql)).
12. Columns without [description](https://www.postgresql.org/docs/current/sql-comment.html) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/columns_without_description.sql)).
13. Columns with [json](https://www.postgresql.org/docs/current/datatype-json.html) type ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/columns_with_json_type.sql)).
14. Columns of [serial types](https://www.postgresql.org/docs/current/datatype-numeric.html#DATATYPE-SERIAL) that are not primary keys ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/columns_with_serial_types.sql)).
15. Functions without [description](https://www.postgresql.org/docs/current/sql-comment.html) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/functions_without_description.sql)).
16. Indexes [with boolean](https://habr.com/ru/companies/tensor/articles/488104/) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/indexes_with_boolean.sql)).
17. Tables with [not valid constraints](https://habr.com/ru/articles/800121/) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/not_valid_constraints.sql)).
18. B-tree indexes [on array columns](https://habr.com/ru/articles/800121/) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/btree_indexes_on_array_columns.sql)).
19. [Sequence overflow](https://habr.com/ru/articles/800121/) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/sequence_overflow.sql)).
20. Primary keys with [serial types](https://wiki.postgresql.org/wiki/Don't_Do_This#Don.27t_use_serial) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/primary_keys_with_serial_types.sql)).
21. Duplicated (completely identical) foreign keys ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/duplicated_foreign_keys.sql)).
22. Intersected (partially identical) foreign keys ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/intersected_foreign_keys.sql)).
23. Objects with possible name overflow ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/possible_object_name_overflow.sql)).
24. Tables are not linked to other tables ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/tables_not_linked_to_others.sql)).
25. Foreign keys [with unmatched column type](https://habr.com/ru/articles/803841/) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/foreign_keys_with_unmatched_column_type.sql)).
26. Tables with zero or one columns ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/tables_with_zero_or_one_column.sql)).
27. Objects whose names do not follow the naming convention ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/objects_not_following_naming_convention.sql)).
28. Columns whose names do not follow the naming convention ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/columns_not_following_naming_convention.sql)).
29. Primary keys with varchar columns instead of uuids ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/primary_keys_with_varchar.sql)).
30. Columns with [varchar(n)](https://www.postgresql.org/docs/current/datatype-character.html) type ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/columns_with_fixed_length_varchar.sql)).
31. Indexes with unnecessary where-clause on not null column ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/indexes_with_unnecessary_where_clause.sql)).
32. Primary keys that are most likely natural keys ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/primary_keys_that_most_likely_natural_keys.sql)).
33. Columns with [money](https://wiki.postgresql.org/wiki/Don%27t_Do_This#Don.27t_use_money) type ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/columns_with_money_type.sql)).
34. Indexes with a [timestamp in the middle](https://habr.com/ru/companies/tensor/articles/488104/) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/indexes_with_timestamp_in_the_middle.sql)).
35. Columns with a [timestamp](https://wiki.postgresql.org/wiki/Don't_Do_This#Don.27t_use_timestamp_.28without_time_zone.29) type ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/columns_with_timestamp_or_timetz_type.sql)).
36. Tables where the primary key columns are not first ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/tables_where_primary_key_columns_not_first.sql)).
37. Tables that have all columns besides the primary key that are nullable ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/tables_where_all_columns_nullable_except_pk.sql)).
38. Columns with [char(n) type](https://wiki.postgresql.org/wiki/Don%27t_Do_This#Don't_use_char(n)) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/columns_with_char_type.sql)).
39. Tables with [inheritance](https://wiki.postgresql.org/wiki/Don%27t_Do_This#Don.27t_use_table_inheritance) ([sql](https://github.com/mfvanek/pg-index-health-sql/blob/master/sql/tables_with_inheritance.sql)).

## Local development

### Linting

#### macOS/Linux

To run super-linter locally:

```shell
docker run \
  -e RUN_LOCAL=true \
  -e USE_FIND_ALGORITHM=true \
  -e VALIDATE_SQLFLUFF=true \
  -v $(pwd):/tmp/lint \
  ghcr.io/super-linter/super-linter:slim-v8.2.1
```

#### Windows

Use `cmd` on Windows:

```shell
docker run ^
  -e RUN_LOCAL=true ^
  -e USE_FIND_ALGORITHM=true ^
  -e VALIDATE_SQLFLUFF=true ^
  -v "%cd%":/tmp/lint ^
  ghcr.io/super-linter/super-linter:slim-v8.2.1
```

See https://github.com/super-linter/super-linter/blob/main/dependencies/python/sqlfluff.txt

```shell
docker run --rm ^
  -v "%cd%\.github\linters\.sqlfluff":/sql/.sqlfluff:ro ^
  -v "%cd%":/sql ^
  -e SQLFLUFF_CONFIG=/sql/.sqlfluff ^
  sqlfluff/sqlfluff:3.4.2 lint /sql
```
