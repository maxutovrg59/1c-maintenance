#!/bin/bash
# Дополнительная очистка старых файлов техжурнала. Основную ротацию делает сама 1С
# через атрибут history="N" в logcfg.xml (см. tj_setup/logcfg.xml) — этот скрипт
# страхует на случай, если по каким-то ИБ/процессам штатная очистка не сработала.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
LOG_FILE="$LOG_DIR/tj_cleanup.log"

log INFO "=== Доп. очистка технологического журнала ==="

if [[ ! -d "$TJ_LOG_DIR" ]]; then
    log WARN "Каталог техжурнала $TJ_LOG_DIR не найден — пропуск очистки"
    exit 0
fi

deleted_count=$(find "$TJ_LOG_DIR" -type f -name "*.log" -mtime +"$TJ_RETENTION_DAYS" -print -delete 2>/dev/null | wc -l)
log INFO "Удалено файлов старше $TJ_RETENTION_DAYS дней: $deleted_count"

find "$TJ_LOG_DIR" -mindepth 1 -type d -empty -delete 2>/dev/null

log INFO "=== Завершено ==="
