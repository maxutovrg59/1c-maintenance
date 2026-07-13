#!/bin/bash
# Ежедневная проверка кластера серверов 1С через rac: список ИБ, рабочие процессы,
# аварийные/тяжёлые по памяти процессы.
#
# ВНИМАНИЕ: точный формат вывода rac (имена свойств process/cluster) может отличаться
# между сборками платформы. Перед первым запуском на боевом сервере сверить вывод
# `rac process --cluster=<uuid> list <host>:<port>` с разбором ниже (awk по "имя: значение")
# и при необходимости поправить имена свойств.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
LOG_FILE="$LOG_DIR/rac_health_check.log"

require_cmd "$RAC_BIN"

RAS_ADDR="${RAS_HOST}:${RAS_PORT}"

log INFO "=== Проверка кластера серверов 1С (rac, $RAS_ADDR) ==="

cluster_uuid=$("$RAC_BIN" cluster list "$RAS_ADDR" 2>>"$LOG_FILE" | awk -F': ' '/^cluster/{print $2; exit}')

if [[ -z "$cluster_uuid" ]]; then
    die "Не удалось получить UUID кластера через 'rac cluster list $RAS_ADDR'"
fi
log INFO "Кластер: $cluster_uuid"

log INFO "--- Информационные базы кластера ---"
"$RAC_BIN" infobase summary list \
    --cluster="$cluster_uuid" \
    --cluster-user="$RAC_CLUSTER_USER" --cluster-pwd="$RAC_CLUSTER_PWD" \
    "$RAS_ADDR" >>"$LOG_FILE" 2>&1

proc_info=$("$RAC_BIN" process list \
    --cluster="$cluster_uuid" \
    --cluster-user="$RAC_CLUSTER_USER" --cluster-pwd="$RAC_CLUSTER_PWD" \
    "$RAS_ADDR" 2>>"$LOG_FILE")

log INFO "--- Рабочие процессы кластера ---"
echo "$proc_info" >>"$LOG_FILE"

high_mem_count=$(echo "$proc_info" \
    | awk -F': ' -v limit="$RAC_PROCESS_MEM_LIMIT_KB" '/^ *memory-size/{gsub(/ /,"",$2); if ($2+0>limit) c++} END{print c+0}')

if (( high_mem_count > 0 )); then
    log WARN "Рабочих процессов с memory-size > ${RAC_PROCESS_MEM_LIMIT_KB} КБ: $high_mem_count (см. вывод выше)"
else
    log INFO "Тяжёлых по памяти рабочих процессов не обнаружено"
fi

log INFO "=== Завершено ==="
