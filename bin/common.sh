#!/bin/bash
# Общие функции для регламентных скриптов. Подключается через `source` в начале каждого скрипта.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck source=../etc/env.conf
source "$BASE_DIR/etc/env.conf"

if [[ -f "$BASE_DIR/etc/rac.secret" ]]; then
    # shellcheck source=../etc/rac.secret
    source "$BASE_DIR/etc/rac.secret"
fi

if [[ -n "${PGPASSFILE:-}" ]]; then
    export PGPASSFILE
fi

mkdir -p "$LOG_DIR"

# LOG_FILE должен быть задан в вызывающем скрипте до первого вызова log/die.
log() {
    local level="$1"; shift
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" >> "${LOG_FILE:-$LOG_DIR/common.log}"
}

die() {
    log ERROR "$*"
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Не найдена команда: $1"
}
