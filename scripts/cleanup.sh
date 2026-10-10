#!/usr/bin/env bash
# Tear down AWS resources created by this system.
# Usage:
#   ./scripts/cleanup.sh           # dry run
#   ./scripts/cleanup.sh --yes     # delete
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

cd "${APP_DIR}"
"$(app_python)" infrastructure/cleanup.py "$@"
