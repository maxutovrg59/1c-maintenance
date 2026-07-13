#!/bin/bash
# Ежедневная проверка состояния PostgreSQL: долгие запросы, блокировки, место под PGDATA.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
LOG_FILE="$LOG_DIR/pg_health_check.log"

require_cmd psql
require_cmd df

PSQL_BASE=(psql -X -A -t -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPERUSER")

log INFO "=== Проверка состояния PostgreSQL ==="

long_queries=$("${PSQL_BASE[@]}" -d postgres -F' | ' -c "
SELECT pid, now()-query_start AS duration, usename, datname, left(query,120)
FROM pg_stat_activity
WHERE state != 'idle' AND now()-query_start > interval '5 minutes'
ORDER BY duration DESC;" 2>>"$LOG_FILE")

if [[ -n "$long_queries" ]]; then
    log WARN "Обнаружены запросы, выполняющиеся дольше 5 минут:"
    echo "$long_queries" >>"$LOG_FILE"
else
    log INFO "Долгих запросов (>5 мин) нет"
fi

blocked=$("${PSQL_BASE[@]}" -d postgres -F' | ' -c "
SELECT blocked_locks.pid AS blocked_pid, blocking_locks.pid AS blocking_pid,
       now()-blocked_activity.query_start AS wait_time
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
   AND blocking_locks.pid != blocked_locks.pid
   AND blocking_locks.granted
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted
  AND now()-blocked_activity.query_start > interval '1 minute';" 2>>"$LOG_FILE")

if [[ -n "$blocked" ]]; then
    log WARN "Обнаружены блокировки дольше 1 минуты:"
    echo "$blocked" >>"$LOG_FILE"
else
    log INFO "Долгих блокировок (>1 мин) нет"
fi

pgdata=$("${PSQL_BASE[@]}" -d postgres -c "SHOW data_directory;" 2>>"$LOG_FILE")
if [[ -n "$pgdata" && -d "$pgdata" ]]; then
    used_percent=$(df --output=pcent "$pgdata" | tail -1 | tr -dc '0-9')
    log INFO "Место под PGDATA ($pgdata): занято ${used_percent}%"
    if (( used_percent > 85 )); then
        log WARN "Мало места под PGDATA: занято ${used_percent}%"
    fi
else
    log ERROR "Не удалось определить data_directory через psql"
fi

log INFO "=== Завершено ==="
