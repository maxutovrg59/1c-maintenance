#!/bin/bash
# Еженедельный тест восстановления: разворачивает самый свежий бэкап каждой ИБ
# во временную БД, проверяет, что таблицы восстановились, и удаляет временную БД.
# Единственный надёжный способ убедиться, что бэкап реально рабочий.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
LOG_FILE="$LOG_DIR/restore_test.log"

require_cmd pg_restore
require_cmd psql

PSQL_BASE=(psql -X -A -t -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPERUSER")

log INFO "=== Еженедельный тест восстановления бэкапов ==="
status=0

for ib in "${!INFOBASES[@]}"; do
    latest=$(find "$BACKUP_DIR" -name "${ib}_*.dump" -type f -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | head -1 | cut -d' ' -f2-)

    if [[ -z "$latest" ]]; then
        log ERROR "Нет бэкапа для ИБ '$ib' — тест восстановления невозможен"
        status=1
        continue
    fi

    test_db="restoretest_${ib}"
    log INFO "Восстановление '$latest' во временную БД '$test_db'"

    "${PSQL_BASE[@]}" -d postgres -c "DROP DATABASE IF EXISTS $test_db;" >>"$LOG_FILE" 2>&1
    "${PSQL_BASE[@]}" -d postgres -c "CREATE DATABASE $test_db;" >>"$LOG_FILE" 2>&1

    if pg_restore -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPERUSER" -d "$test_db" "$latest" >>"$LOG_FILE" 2>&1; then
        tbl_count=$("${PSQL_BASE[@]}" -d "$test_db" -c \
            "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';")
        log INFO "OK: восстановлено, таблиц в public: $tbl_count"
    else
        log ERROR "ОШИБКА восстановления бэкапа для ИБ '$ib' ('$latest')"
        status=1
    fi

    "${PSQL_BASE[@]}" -d postgres -c "DROP DATABASE IF EXISTS $test_db;" >>"$LOG_FILE" 2>&1
done

log INFO "=== Завершено (статус=$status) ==="
exit "$status"
