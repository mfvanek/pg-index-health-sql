/*
 * Copyright (c) 2019-2023. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds the slowest queries by total execution time.
-- Requires the pg_stat_statement extension https://www.postgresql.org/docs/current/pgstatstatements.html
-- Compatible with PostgreSQL 13 and higher.
select
    round(total_exec_time::numeric, 3) as total_time_ms,
    calls as calls_count,
    round(mean_exec_time::numeric, 3) as average_time_ms,
    query
from pg_stat_statements
order by total_exec_time desc
limit :limit_count::integer;
