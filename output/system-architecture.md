# NovaMart Multi-Agent Support — System Architecture

## Overview

NovaMart’s customer support AI layer uses an **Orchestrator → Workers** pattern built with the [Strands Agents SDK](https://strandsagents.com/docs/) (v1.57+) and Amazon Bedrock AgentCore.

A central **OrchestratorAgent** (Claude Haiku) routes each request to specialist workers. Workers write findings into a shared DynamoDB **WorkflowState** record with optimistic locking. The **CommunicationAgent** always composes the final customer-facing reply.

## Component Diagram

```mermaid
flowchart TB
  Customer([Customer Request]) --> Orch[OrchestratorAgent<br/>Claude Haiku 4.5]

  Orch -->|order / return / account| Inv[InventoryAgent<br/>Claude Sonnet 4.5]
  Orch -->|policy questions| Pol[PolicyAgent<br/>Claude Sonnet 4.5]
  Orch -->|after inventory| Ref[RefundAgent<br/>Claude Sonnet 4.5]
  Orch -->|always last| Com[CommunicationAgent<br/>Claude Sonnet 4.5]

  Inv --> DDB[(WorkflowStateTable<br/>DynamoDB)]
  Pol --> DDB
  Ref --> DDB
  Com --> DDB

  Inv --> Orders[(Orders + Customers<br/>DynamoDB)]
  Ref --> Orders

  Pol --> Ret[ReturnsPolicyRetriever]
  Pol --> Ship[ShippingPolicyRetriever]
  Pol --> War[WarrantyPolicyRetriever]

  Ret --> KB1[(Returns KB<br/>S3 Vectors)]
  Ship --> KB2[(Shipping KB<br/>S3 Vectors)]
  War --> KB3[(Warranty KB<br/>S3 Vectors)]

  Orch -.->|Bedrock Guardrails| GR{{Guardrail}}
  Orch -.->|AgentCore Runtime| RT{{Runtime + Memory}}
  Orch -.->|X-Ray + CloudWatch| OBS{{Observability}}
```

## Request Flows

| Scenario | Routing |
|----------|---------|
| Return / refund / order status | `initialize_session` → Inventory → Refund → Communication |
| Policy meaning (windows, rates, warranty) | `initialize_session` → Policy (3 parallel KB retrievers) → Communication |
| Account tier questions | `initialize_session` → Inventory → Communication |
| Math / pricing calculations | `initialize_session` → Communication only |

## Shared State (Optimistic Locking)

```mermaid
sequenceDiagram
  participant O as Orchestrator
  participant W as Worker Agent
  participant S as WorkflowState

  O->>S: initialize_session (version=0)
  O->>S: read state (expected_version=N)
  O->>W: invoke with session context
  W-->>O: findings
  O->>S: conditional update version=N → N+1
  Note over S: ConditionalCheckFailed → retry with fresh version
```

## Model Backends

| `.env` switch | Provider | Strands class |
|---------------|----------|---------------|
| `USE_BEDROCK_MANTLE=false` (default) | `bedrock-runtime` Converse API | `BedrockModel` |
| `USE_BEDROCK_MANTLE=true` | `bedrock-mantle` OpenAI-compatible | `OpenAIModel` + `bedrock_mantle_config` |

## Deployment Topology

1. **CloudFormation** (`infrastructure/starter_stack.yaml`) — DynamoDB, S3, S3 Vectors indexes, IAM role, log group  
2. **Bedrock Knowledge Bases** (console) — Returns / Shipping / Warranty synced to S3 Vectors  
3. **AgentCore CLI** — packages `build/runtime/` and deploys HTTP runtime  
4. **Guardrail + Memory + Observability** — created/configured by `agent_orchestrator.py deploy`

## Key Modules

| Path | Role |
|------|------|
| `src/src/agent_orchestrator.py` | Agent builders, routing tools, deploy pipeline |
| `src/src/bedrock_kb_retrieval.py` | KB retrieve helper for PolicyAgent |
| `src/src/agent_observability.py` | X-Ray + CloudWatch tooling |
| `src/config.py` | Lazy CloudFormation exports + `.env` |
| `scripts/` | Script-driven setup, deploy, test, cleanup |
