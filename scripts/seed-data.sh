#!/usr/bin/env bash
# Seed DynamoDB customers/orders and upload policy documents to S3.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

cd "${APP_DIR}"
"$(app_python)" infrastructure/seed_data.py
