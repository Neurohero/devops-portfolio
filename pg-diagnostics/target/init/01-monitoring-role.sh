#!/bin/sh
# Роль только для сбора статистики: pg_monitor даёт pg_stat_* и pg_stat_statements
# без прав суперюзера. Пароль берётся из окружения, в репозитории его нет.
set -eu
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v pw="$PROFILER_PASSWORD" <<'SQL'
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SELECT format('CREATE ROLE profiler LOGIN PASSWORD %L IN ROLE pg_monitor', :'pw') \gexec
-- pg_profile сбрасывает pg_stat_statements после снимка — даём только эту функцию
SELECT format('GRANT EXECUTE ON FUNCTION %s TO profiler', oid::regprocedure)
FROM pg_proc WHERE proname = 'pg_stat_statements_reset' \gexec
SQL
