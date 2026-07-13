#!/bin/bash
# Ежедневный логический бэкап баз 1С (pg_dump -Fc) с проверкой места и ротацией по сроку.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
LOG_FILE="$LOG_DIR/pg_backup.log"

require_cmd pg_dump
require_cmd df

mkdir -p "$BACKUP_DIR"

log INFO "=== Старт бэкапа ==="

used_percent=$(df --output=pcent "$BACKUP_DIR" | tail -1 | tr -dc '0-9')
free_percent=$((100 - used_percent))
if (( free_percent < BACKUP_MIN_FREE_PERCENT )); then
    die "Недостаточно места в $BACKUP_DIR: свободно ${free_percent}%, требуется минимум ${BACKUP_MIN_FREE_PERCENT}%"
fi

TS="$(date '+%Y%m%d_%H%M%S')"
status=0

for ib in "${!INFOBASES[@]}"; do
    dbname="${INFOBASES[$ib]}"
    dumpfile="$BACKUP_DIR/${ib}_${TS}.dump"
    log INFO "Бэкап ИБ '$ib' (БД '$dbname') -> $dumpfile"
    if pg_dump -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPERUSER" -Fc -f "$dumpfile" "$dbname" >>"$LOG_FILE" 2>&1; then
        log INFO "OK: $dumpfile ($(du -h "$dumpfile" | cut -f1))"
    else
        log ERROR "Ошибка бэкапа ИБ '$ib' (БД '$dbname')"
        status=1
    fi
done

log INFO "Удаление бэкапов старше $BACKUP_RETENTION_DAYS дней из $BACKUP_DIR"
find "$BACKUP_DIR" -name '*.dump' -type f -mtime +"$BACKUP_RETENTION_DAYS" -print -delete >>"$LOG_FILE" 2>&1

log INFO "=== Завершено (статус=$status) ==="
exit "$status"
