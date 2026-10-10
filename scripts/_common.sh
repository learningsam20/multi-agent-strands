#!/usr/bin/env bash
# Shared helpers for NovaMart scripts — load src/.env and export AWS_PROFILE.
APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${APP_ROOT}/src"
ENV_FILE="${APP_DIR}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-$AWS_REGION}"
export PROJECT_NAME="${PROJECT_NAME:-udacity-agentcore}"

# Access keys in .env take precedence over profile login-session credentials.
if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  export AWS_ACCESS_KEY_ID
  export AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN || true
  # Avoid profile login creds overriding env keys in some CLI paths
  unset AWS_PROFILE || true
else
  export AWS_PROFILE="${AWS_PROFILE:-multi-agent-strands}"
fi

app_python() {
  if [[ -x "${APP_DIR}/.venv/bin/python" ]]; then
    echo "${APP_DIR}/.venv/bin/python"
  else
    echo "python3"
  fi
}
