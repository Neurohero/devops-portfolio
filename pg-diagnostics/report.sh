#!/bin/sh
# HTML-отчёт pg_profile о нагрузке за интервал:
#   sh report.sh "2026-09-28 10:00" "2026-09-28 12:00" > report.html
set -eu
[ $# -eq 2 ] || { echo "usage: $0 FROM TO > report.html" >&2; exit 1; }
cd "$(dirname "$0")"
if docker compose version >/dev/null 2>&1; then dc="docker compose"; else dc="docker-compose"; fi
echo "SELECT get_report('target', tstzrange(:'from', :'to'));" |
    $dc exec -T repository psql -U postgres -d diag -qAt -v ON_ERROR_STOP=1 -v from="$1" -v to="$2"
