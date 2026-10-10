#!/usr/bin/env bash
# Deploy guardrail, AgentCore Runtime, memory, and observability.
# Prerequisites: foundation stack, seed data, three KB IDs in .env, AgentCore CLI.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

cd "${APP_DIR}"
AUTH_DESC="${AWS_PROFILE:-access-keys}"
echo "==> Deploying multi-agent system (auth=${AUTH_DESC})"
"$(app_python)" src/agent_orchestrator.py deploy
echo "Copy printed AGENTCORE_RUNTIME_ARN / GUARDRAIL_* values into .env"
