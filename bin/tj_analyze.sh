#!/bin/bash
# Ежедневный разбор технологического журнала 1С за прошедшие сутки: количество
# ошибок, конфликтов блокировок, топ самых долгих запросов к СУБД.
#
# ВНИМАНИЕ: это базовый текстовый разбор (grep/awk по логу техжурнала), а не
# полноценный парсер формата ТЖ. Для более глубокого анализа (разбор по
# конкретным ИБ, пользователям, вызовам) потребуется доработка под конкретную
# структуру логов на сервере.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
LOG_FILE="$LOG_DIR/tj_analyze.log"

log INFO "=== Анализ технологического журнала за $(date '+%Y-%m-%d') ==="

if [[ ! -d "$TJ_LOG_DIR" ]]; then
    log WARN "Каталог техжурнала $TJ_LOG_DIR не найден — пропуск анализа"
    exit 0
fi

# Файлы техжурнала 1С именуются YYMMDDHH.log (год-месяц-день-час, 2 цифры на год)
TODAY_PREFIX=$(date '+%y%m%d')

mapfile -t found_files < <(find "$TJ_LOG_DIR" -type f -name "${TODAY_PREFIX}*.log" 2>/dev/null)

if [[ ${#found_files[@]} -eq 0 ]]; then
    log WARN "Файлы техжурнала за сегодня (префикс $TODAY_PREFIX) не найдены в $TJ_LOG_DIR"
    exit 0
fi

log INFO "Файлов техжурнала за сегодня: ${#found_files[@]}"

excp_count=$(grep -h "EXCP" "${found_files[@]}" 2>/dev/null | wc -l)
log INFO "Событий EXCP (исключения): $excp_count"

tlock_count=$(grep -h "TLOCK" "${found_files[@]}" 2>/dev/null | wc -l)
log INFO "Событий TLOCK (конфликты управляемых блокировок): $tlock_count"

deadlock_count=$(grep -h "TDEADLOCK" "${found_files[@]}" 2>/dev/null | wc -l)
log INFO "Событий TDEADLOCK (конфликты блокировок СУБД): $deadlock_count"

log INFO "--- Топ-20 самых долгих запросов к СУБД (DBMSSQL, Duration в мкс) ---"
grep -h "DBMSSQL" "${found_files[@]}" 2>/dev/null \
    | grep -oE 'Duration=[0-9]+.*' \
    | sort -t= -k2 -rn \
    | head -20 >>"$LOG_FILE"

if (( excp_count > 0 )); then
    log INFO "--- Примеры EXCP (первые 10) ---"
    grep -h "EXCP" "${found_files[@]}" 2>/dev/null | head -10 >>"$LOG_FILE"
fi

log INFO "=== Завершено ==="
