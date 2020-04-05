/*
 * Copyright (c) 2019-2020. Ivan Vakhrushev and others.
 * https://github.com/mfvanek/pg-index-health-sql
 *
 * Licensed under the Apache License 2.0
 */

-- Finds the slowest queries by total execution time.
-- Requires the pg_stat_statement extension.
select
    round(total_time::numeric, 3) as total_time_ms,
    calls as calls_count,
    round(mean_time::numeric, 3) as average_time_ms,
    query
from pg_stat_statements
order by total_time desc
limit :limit_count::integer;
