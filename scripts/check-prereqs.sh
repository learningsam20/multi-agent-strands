#!/usr/bin/env bash
# Validate local tooling and AWS credentials before deploy.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT}/src"
OK=0
FAIL=0

pass() { echo "  [OK]  $*"; OK=$((OK + 1)); }
fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }
info() { echo "  [..]  $*"; }

echo "==> NovaMart prerequisite check"
echo

# Python / venv
if [[ -x "${APP_DIR}/.venv/bin/python" ]]; then
  VER="$("${APP_DIR}/.venv/bin/python" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
  pass "Python venv (${VER})"
  if "${APP_DIR}/.venv/bin/python" -c "from importlib.metadata import version; v=version('strands-agents'); assert tuple(int(x) for x in v.split('.')[:2]) >= (1,57)" 2>/dev/null; then
    pass "strands-agents >= 1.57 ($("${APP_DIR}/.venv/bin/python" -c 'from importlib.metadata import version; print(version("strands-agents"))'))"
  else
    fail "strands-agents missing or < 1.57 — run ./scripts/setup.sh"
  fi
else
  fail "src/.venv missing — run ./scripts/setup.sh"
fi

# .env
if [[ -f "${APP_DIR}/.env" ]]; then
  pass "src/.env present"
else
  fail "src/.env missing — copy from src/.env.example"
fi

# Node / uv / agentcore
if command -v node >/dev/null 2>&1; then
  pass "Node.js $(node --version)"
else
  fail "Node.js not found (need 20+)"
fi

if command -v uv >/dev/null 2>&1; then
  pass "uv $(uv --version | head -1)"
else
  fail "uv not found — https://docs.astral.sh/uv/"
fi

if command -v agentcore >/dev/null 2>&1; then
  AC_VER="$(agentcore --version 2>/dev/null | head -1)"
  pass "agentcore CLI (${AC_VER})"
  case "${AC_VER}" in
    0.3*|0.4*|0.5*|1.*) ;;
    *) info "Recommended agentcore >= 0.30.0 (npm i -g @aws/agentcore@0.30.0)" ;;
  esac
else
  fail "agentcore CLI missing — npm install -g @aws/agentcore@0.30.0"
fi

# AWS credentials
if command -v aws >/dev/null 2>&1; then
  if aws sts get-caller-identity >/dev/null 2>&1; then
    IDENT="$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)"
    pass "AWS credentials (${IDENT})"
  else
    fail "AWS credentials invalid/expired — run: aws login --profile admin   (or refresh keys)"
  fi
else
  fail "AWS CLI not found"
fi

# Stack (informational)
REGION="${AWS_REGION:-us-east-1}"
STACK="${PROJECT_NAME:-udacity-agentcore}"
if aws cloudformation describe-stacks --stack-name "${STACK}" --region "${REGION}" >/dev/null 2>&1; then
  STATUS="$(aws cloudformation describe-stacks --stack-name "${STACK}" --region "${REGION}" --query 'Stacks[0].StackStatus' --output text)"
  pass "CloudFormation stack ${STACK} (${STATUS})"
else
  info "CloudFormation stack ${STACK} not found — run ./scripts/deploy-infra.sh after auth"
fi

# KB IDs
if [[ -f "${APP_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "${APP_DIR}/.env"; set +a
  for key in RETURNS_KB_ID SHIPPING_KB_ID WARRANTY_KB_ID; do
    if [[ -n "${!key:-}" ]]; then
      pass "${key} set"
    else
      info "${key} empty — create/sync Knowledge Bases in AWS Console, then edit src/.env"
    fi
  done
fi

echo
echo "Result: ${OK} ok, ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
