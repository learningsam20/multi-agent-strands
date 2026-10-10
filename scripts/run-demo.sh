#!/usr/bin/env bash
# Single end-to-end refund scenario (local agents).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

cd "${APP_DIR}"
"$(app_python)" src/demo.py
