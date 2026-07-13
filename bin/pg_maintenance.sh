#!/bin/bash
# Еженедельное обслуживание: ANALYZE базы целиком + точечный VACUUM ANALYZE
# для таблиц с высокой долей мёртвых кортежей (актуально для регистров 1С
# с частыми UPDATE, где штатный autovacuum не всегда успевает).

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
LOG_FILE="$LOG_DIR/pg_maintenance.log"

require_cmd psql

PSQL_BASE=(psql -X -A -t -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPERUSER")

log INFO "=== Еженедельное обслуживание PostgreSQL ==="

for ib in "${!INFOBASES[@]}"; do
    dbname="${INFOBASES[$ib]}"
    log INFO "--- БД '$dbname' (ИБ '$ib') ---"

    log INFO "ANALYZE всей базы"
    "${PSQL_BASE[@]}" -d "$dbname" -c "ANALYZE;" >>"$LOG_FILE" 2>&1

    bloated=$("${PSQL_BASE[@]}" -d "$dbname" -F'|' -c "
    SELECT schemaname||'.'||relname, n_dead_tup, n_live_tup,
           round(n_dead_tup::numeric / GREATEST(n_live_tup,1) * 100, 1) AS dead_pct
    FROM pg_stat_user_tables
    WHERE n_dead_tup > 10000
    ORDER BY dead_pct DESC
    LIMIT 10;" 2>>"$LOG_FILE")

    if [[ -z "$bloated" ]]; then
        log INFO "Таблиц с существенным bloat не найдено"
        continue
    fi

    log INFO "Таблицы-кандидаты на VACUUM (таблица|dead|live|dead_pct):"
    echo "$bloated" >>"$LOG_FILE"

    while IFS='|' read -r tbl dead live pct; do
        [[ -z "$tbl" ]] && continue
        log INFO "VACUUM ANALYZE $tbl (мёртвых кортежей: ${pct}%)"
        "${PSQL_BASE[@]}" -d "$dbname" -c "VACUUM (ANALYZE) $tbl;" >>"$LOG_FILE" 2>&1
    done <<< "$bloated"
done

log INFO "=== Завершено ==="
