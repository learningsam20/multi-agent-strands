#!/usr/bin/env bash
# Run the three local end-to-end scenarios (refund / policy / math).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

cd "${APP_DIR}"
"$(app_python)" src/agent_orchestrator.py test
