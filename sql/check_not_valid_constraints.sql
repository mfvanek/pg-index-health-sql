/*
 * Copyright (c) 2019-2024. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */
SELECT
    t.relname AS table_name, -- Name of the table
    c.conname AS constraint_name, -- Name of the constraint
    c.contype AS constraint_type  -- Type of the constraint
FROM
    pg_catalog.pg_constraint c
    JOIN pg_catalog.pg_class t ON t.oid = c.conrelid
    JOIN pg_catalog.pg_namespace n ON n.oid = t.relnamespace
WHERE
    NOT c.convalidated -- Constraints that have not yet been validated
    AND c.contype IN ('c', 'f') -- Focus on check and foreign key constraints
    AND n.nspname = :schema_name_param::text; -- Make the query schema-aware