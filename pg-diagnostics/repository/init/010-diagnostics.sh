#!/bin/sh
set -eu
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v pw="$PROFILER_PASSWORD" <<'SQL'
CREATE EXTENSION IF NOT EXISTS dblink;
CREATE EXTENSION IF NOT EXISTS pg_profile;

-- pg_profile при установке регистрирует саму БД-репозиторий как 'local'; нам нужен только target
SELECT drop_server('local');
SELECT create_server('target', 'host=target port=5432 dbname=app user=profiler password=' || :'pw');

-- История ожиданий блокировок: pg_profile показывает агрегаты за интервал,
-- а «кто кого держал в 14:03» видно только из частых срезов pg_stat_activity.
CREATE SERVER target_srv FOREIGN DATA WRAPPER dblink_fdw OPTIONS (host 'target', port '5432', dbname 'app');
SELECT format('CREATE USER MAPPING FOR PUBLIC SERVER target_srv OPTIONS (user %L, password %L)', 'profiler', :'pw') \gexec

CREATE TABLE lock_waits (
    ts          timestamptz NOT NULL,
    pid         int,
    usename     name,
    datname     name,
    wait_event  text,
    state       text,
    blocked_by  int[],
    waiting     interval,
    query       text
);
SELECT create_hypertable('lock_waits', by_range('ts', INTERVAL '1 day'));
SELECT add_retention_policy('lock_waits', INTERVAL '14 days');

CREATE FUNCTION collect_lock_waits() RETURNS bigint LANGUAGE sql AS $fn$
    WITH ins AS (
        INSERT INTO lock_waits
        SELECT now(), t.*
        FROM dblink('target_srv', $q$
            SELECT pid, usename, datname, wait_event, state,
                   pg_blocking_pids(pid), now() - query_start, left(query, 500)
            FROM pg_stat_activity
            WHERE wait_event_type = 'Lock'
        $q$) AS t(pid int, usename name, datname name, wait_event text, state text,
                  blocked_by int[], waiting interval, query text)
        RETURNING 1
    )
    SELECT count(*) FROM ins
$fn$;
SQL
