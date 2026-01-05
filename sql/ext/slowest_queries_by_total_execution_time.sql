/*
 * Copyright (c) 2019-2026. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds the slowest queries by total execution time.
-- Requires the pg_stat_statement extension.
-- Compatible with PostgreSQL 12 and lower.
-- noqa: disable=PRS
select
    calls as calls_count,
    query,
    round(total_time::numeric, 3) as total_time_ms,
    round(mean_time::numeric, 3) as average_time_ms
from pg_stat_statements
order by total_time desc
limit :limit_count::integer;
