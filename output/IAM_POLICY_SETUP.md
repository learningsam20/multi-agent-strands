# IAM operator policy — attach in AWS Console

The `multi-agent-strands` login identity needs broad deploy/runtime permissions for this system (CloudFormation, IAM, Bedrock, AgentCore, DynamoDB, S3/S3 Vectors, Logs, X-Ray, CDK bootstrap).

## Policy file

[`iam-operator-policy.json`](./iam-operator-policy.json)

## Attach in the console

1. Sign in as an admin for account `426084279197` (or your account).
2. Open **IAM → Policies → Create policy → JSON**.
3. Paste the contents of `iam-operator-policy.json`.
4. Name it e.g. `NovaMartMultiAgentOperator`.
5. Attach it to the IAM user / role / Identity Center permission set that backs the **`multi-agent-strands`** profile.
6. Re-login:

```bash
./scripts/aws-login.sh
aws sts get-caller-identity --profile multi-agent-strands
```

## What it covers

| Area | Why |
|------|-----|
| CloudFormation | `udacity-agentcore` stack + AgentCore CDK (`AgentCore-udacity-default`) + `CDKToolkit` |
| IAM | Create/pass `udacity-agentcore-agentcore-role` and CDK bootstrap roles |
| DynamoDB / S3 / S3 Vectors | Tables, policy docs, KB vector store |
| Bedrock | Model invoke, Guardrails, Knowledge Bases + Retrieve |
| Bedrock AgentCore | Runtime deploy, Memory, Gateway, invoke |
| Logs + X-Ray | Observability + Transaction Search |
| SSM + ECR | First-time CDK bootstrap |

This policy is intentionally broad for a **dev/operator** principal. Tighten `Resource` ARNs for production.

## After attach

```bash
./scripts/aws-login.sh
./scripts/deploy-infra.sh
```
