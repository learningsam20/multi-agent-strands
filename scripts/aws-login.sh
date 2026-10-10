#!/usr/bin/env bash
# Authenticate with the AWS profile from src/.env (default: multi-agent-strands).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  echo "==> Using IAM access keys from .env (skipping aws login)"
  aws sts get-caller-identity --region "${AWS_REGION}"
  echo "Done."
  exit 0
fi

PROFILE="${AWS_PROFILE:-multi-agent-strands}"
echo "==> AWS login with profile: ${PROFILE} (region: ${AWS_REGION})"
aws login --profile "${PROFILE}"

echo "==> Verifying identity..."
aws sts get-caller-identity --profile "${PROFILE}" --region "${AWS_REGION}"
echo "Done."
