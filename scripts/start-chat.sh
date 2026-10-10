#!/usr/bin/env bash
# Interactive multi-agent chat with live routing trace.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

cd "${APP_DIR}"
"$(app_python)" src/agent_orchestrator.py chat
