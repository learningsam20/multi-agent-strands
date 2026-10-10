#!/usr/bin/env bash
# Run the automated validation suite.
# Usage: ./scripts/run-tests.sh [task2|task3|task4|task5|task6|all]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"
TARGET="${1:-all}"

cd "${APP_DIR}"
"$(app_python)" tests/test_agent.py "${TARGET}"
