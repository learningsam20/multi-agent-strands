# Submission checklist

Status of the Udacity Multi-Agent Graph deliverables.

## Required files

| Deliverable | Location | Status |
|-------------|----------|--------|
| `src/agent_orchestrator.py` with all TODOs done | [`src/src/agent_orchestrator.py`](../src/src/agent_orchestrator.py) | Done (no remaining TODOs) |
| Populated `.env` | `src/.env` (gitignored) | Done — KB IDs, `AGENTCORE_RUNTIME_ARN`, `GUARDRAIL_ID` / `GUARDRAIL_VERSION` set |
| Test score screenshot **120/120** | [`screenshots/test-score-120.png`](screenshots/test-score-120.png) | Done |
| X-Ray Service Map screenshot | [`screenshots/xray-service-map.png`](screenshots/xray-service-map.png) | Done |

## Automated score

```bash
cd src && source .venv/bin/activate
python tests/test_agent.py all
# Score: 120/120 pts (100%)
```

Re-capture the score screenshot anytime with:

```bash
./scripts/run-tests.sh all
```

## X-Ray Service Map

Live scenarios were run with:

```bash
cd src && python src/agent_orchestrator.py test
```

Published traces (us-east-1):

- `1-6aca0575-d442895b97056287072d2e5b` — return / inventory → refund → communication
- `1-6aca059c-633c5a35f105a0406cb42f26` — policy RAG (parallel KBs) → communication
- `1-6aca05b9-67c980217efab65c189bb19d` — math → communication

Service Map URL:

https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#xray:service-map/map

Graph captured from AWS X-Ray `GetServiceGraph` after those traces landed shows:

`Client → NovaMart-Orchestrator → InventoryAgent | PolicyAgent | RefundAgent | CommunicationAgent | KnowledgeBase:returns | KnowledgeBase:shipping | KnowledgeBase:warranty`

## Rubric coverage (summary)

| Area | Result |
|------|--------|
| Task 2 — workers, parallel RAG, orchestrator + WorkflowState | Pass |
| Task 3 — Guardrail + AgentCore Runtime | Pass |
| Task 4 — AgentCore Memory (SESSION_SUMMARY, 7 days) | Pass |
| Task 5 — three KBs + `search_all_policies` parallel retrieval | Pass |
| Task 6 — CloudWatch INFO + X-Ray 100% sampling | Pass |
| Industry practices — docstrings, `config.*` model IDs | Pass |

## Optional “stand out” ideas (not required)

Documented in the course rubric only — not part of the scored submission:

- Adversarial guardrail demos with blocked-response screenshots
- DynamoDB `DynamoDbSessionStorage` for local session recall
- CloudWatch dashboard (invocations, latency, guardrail triggers)
- Cognito + frontend against the AgentCore Runtime endpoint
