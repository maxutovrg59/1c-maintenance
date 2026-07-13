#!/bin/bash
# Проверка целостности самого свежего бэкапа каждой ИБ через pg_restore --list
# (без полного восстановления — быстрая проверка, что файл не битый).

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
LOG_FILE="$LOG_DIR/pg_backup_verify.log"

require_cmd pg_restore

log INFO "=== Проверка последних бэкапов ==="
status=0

for ib in "${!INFOBASES[@]}"; do
    latest=$(find "$BACKUP_DIR" -name "${ib}_*.dump" -type f -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | head -1 | cut -d' ' -f2-)

    if [[ -z "$latest" ]]; then
        log ERROR "Нет ни одного файла бэкапа для ИБ '$ib' в $BACKUP_DIR"
        status=1
        continue
    fi

    if pg_restore --list "$latest" >/dev/null 2>>"$LOG_FILE"; then
        log INFO "OK: '$latest' читается корректно"
    else
        log ERROR "ПОВРЕЖДЁН файл бэкапа: '$latest'"
        status=1
    fi
done

log INFO "=== Завершено (статус=$status) ==="
exit "$status"
