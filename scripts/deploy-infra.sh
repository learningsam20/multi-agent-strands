#!/usr/bin/env bash
# Deploy the CloudFormation foundation stack (DynamoDB, S3, S3 Vectors, IAM, logs).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

STACK_NAME="${PROJECT_NAME}"
REGION="${AWS_REGION}"
TEMPLATE="${APP_DIR}/infrastructure/starter_stack.yaml"
PY="$(app_python)"

AUTH_DESC="${AWS_PROFILE:-access-keys}"
echo "==> Deploying foundation stack: ${STACK_NAME} (${REGION}) auth=${AUTH_DESC}"

if [[ -n "${AWS_PROFILE:-}" ]]; then
  aws cloudformation deploy \
    --profile "${AWS_PROFILE}" \
    --stack-name "${STACK_NAME}" \
    --template-file "${TEMPLATE}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "${REGION}" \
    --parameter-overrides "ProjectName=${STACK_NAME}"
else
  aws cloudformation deploy \
    --stack-name "${STACK_NAME}" \
    --template-file "${TEMPLATE}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "${REGION}" \
    --parameter-overrides "ProjectName=${STACK_NAME}"
fi

echo "==> Stack deploy complete. Seeding data..."
cd "${APP_DIR}"
"${PY}" infrastructure/seed_data.py

echo "==> Current config:"
"${PY}" config.py
echo "Done."
