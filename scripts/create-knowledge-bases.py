#!/usr/bin/env python3
"""Create and sync the three NovaMart Bedrock Knowledge Bases (S3 Vectors)."""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

import boto3
from botocore.exceptions import ClientError
from dotenv import load_dotenv

APP_DIR = Path(__file__).resolve().parents[1] / "src"
sys.path.insert(0, str(APP_DIR))
load_dotenv(APP_DIR / ".env")

import config  # noqa: E402

REGION = config.AWS_REGION
# Titan Embed free-tier RPM is often 0 on new accounts; Cohere Embed English v3
# (1024-dim) is on-demand compatible with the S3 Vectors indexes in this stack.
EMBED_MODEL_ARN = f"arn:aws:bedrock:{REGION}::foundation-model/cohere.embed-english-v3"

KB_SPECS = [
    {
        "env_key": "RETURNS_KB_ID",
        "name": "novamart-returns-policy-kb",
        "description": "NovaMart returns policy knowledge base",
        "prefix": "policies/returns/",
        "index_name": config.RETURNS_VECTOR_INDEX,
        "index_arn": (
            f"{config.VECTOR_STORE_BUCKET_ARN}/index/{config.RETURNS_VECTOR_INDEX}"
        ),
    },
    {
        "env_key": "SHIPPING_KB_ID",
        "name": "novamart-shipping-policy-kb",
        "description": "NovaMart shipping policy knowledge base",
        "prefix": "policies/shipping/",
        "index_name": config.SHIPPING_VECTOR_INDEX,
        "index_arn": (
            f"{config.VECTOR_STORE_BUCKET_ARN}/index/{config.SHIPPING_VECTOR_INDEX}"
        ),
    },
    {
        "env_key": "WARRANTY_KB_ID",
        "name": "novamart-warranty-policy-kb",
        "description": "NovaMart warranty policy knowledge base",
        "prefix": "policies/warranty/",
        "index_name": config.WARRANTY_VECTOR_INDEX,
        "index_arn": (
            f"{config.VECTOR_STORE_BUCKET_ARN}/index/{config.WARRANTY_VECTOR_INDEX}"
        ),
    },
]


def _update_env(updates: dict[str, str]) -> None:
    env_path = APP_DIR / ".env"
    lines = env_path.read_text().splitlines()
    keys_done = set()
    out = []
    for line in lines:
        if "=" in line and not line.strip().startswith("#"):
            key = line.split("=", 1)[0].strip()
            if key in updates:
                out.append(f"{key}={updates[key]}")
                keys_done.add(key)
                continue
        out.append(line)
    for key, value in updates.items():
        if key not in keys_done:
            out.append(f"{key}={value}")
    env_path.write_text("\n".join(out) + "\n")


def _find_existing(bedrock_agent, name: str) -> str | None:
    paginator = bedrock_agent.get_paginator("list_knowledge_bases")
    for page in paginator.paginate():
        for summary in page.get("knowledgeBaseSummaries", []):
            if summary.get("name") == name:
                return summary["knowledgeBaseId"]
    return None


def _wait_kb_active(bedrock_agent, kb_id: str, timeout: int = 300) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        kb = bedrock_agent.get_knowledge_base(knowledgeBaseId=kb_id)["knowledgeBase"]
        status = kb.get("status")
        if status == "ACTIVE":
            return
        if status == "FAILED":
            raise RuntimeError(f"KB {kb_id} failed: {kb.get('failureReasons')}")
        time.sleep(5)
    raise TimeoutError(f"KB {kb_id} not ACTIVE after {timeout}s")


def _ensure_data_source(bedrock_agent, kb_id: str, name: str, prefix: str) -> str:
    sources = bedrock_agent.list_data_sources(knowledgeBaseId=kb_id).get(
        "dataSourceSummaries", []
    )
    for ds in sources:
        if ds.get("name") == name:
            return ds["dataSourceId"]

    resp = bedrock_agent.create_data_source(
        knowledgeBaseId=kb_id,
        name=name,
        description=f"S3 data source for {prefix}",
        dataSourceConfiguration={
            "type": "S3",
            "s3Configuration": {
                "bucketArn": f"arn:aws:s3:::{config.POLICY_BUCKET}",
                "inclusionPrefixes": [prefix],
            },
        },
    )
    return resp["dataSource"]["dataSourceId"]


def _sync(bedrock_agent, kb_id: str, data_source_id: str) -> None:
    # Titan Embed free-tier quotas are tight; retry StartIngestionJob on throttle.
    last_exc: Exception | None = None
    job = None
    for attempt in range(1, 9):
        try:
            job = bedrock_agent.start_ingestion_job(
                knowledgeBaseId=kb_id, dataSourceId=data_source_id
            )["ingestionJob"]
            break
        except ClientError as exc:
            last_exc = exc
            code = exc.response.get("Error", {}).get("Code", "")
            msg = str(exc)
            if code in ("ThrottlingException", "ValidationException") and (
                "Too many requests" in msg or "throttl" in msg.lower()
            ):
                wait = min(30 * attempt, 180)
                print(f"    Sync throttled (attempt {attempt}/8), waiting {wait}s...")
                time.sleep(wait)
                continue
            raise
    if job is None:
        raise RuntimeError(f"Could not start ingestion: {last_exc}")

    job_id = job["ingestionJobId"]
    print(f"    Sync started: {job_id}")
    deadline = time.time() + 900
    while time.time() < deadline:
        cur = bedrock_agent.get_ingestion_job(
            knowledgeBaseId=kb_id,
            dataSourceId=data_source_id,
            ingestionJobId=job_id,
        )["ingestionJob"]
        status = cur["status"]
        if status == "COMPLETE":
            print("    Sync COMPLETE")
            return
        if status == "FAILED":
            reasons = cur.get("failureReasons") or []
            joined = " ".join(str(r) for r in reasons)
            if "Too many requests" in joined:
                print("    Sync failed due to model throttle; retrying job...")
                time.sleep(60)
                return _sync(bedrock_agent, kb_id, data_source_id)
            raise RuntimeError(f"Ingestion failed: {reasons}")
        time.sleep(8)
    raise TimeoutError("Ingestion timed out")


def main() -> int:
    bedrock_agent = boto3.client("bedrock-agent", region_name=REGION)
    role_arn = config.AGENTCORE_ROLE_ARN
    ids: dict[str, str] = {}

    print(f"Region: {REGION}")
    print(f"Policy bucket: {config.POLICY_BUCKET}")
    print(f"Vector bucket: {config.VECTOR_STORE_BUCKET_ARN}")
    print(f"KB role: {role_arn}")
    print()

    for spec in KB_SPECS:
        print(f"==> {spec['name']}")
        kb_id = _find_existing(bedrock_agent, spec["name"])
        if kb_id:
            print(f"    Reusing existing KB: {kb_id}")
        else:
            try:
                resp = bedrock_agent.create_knowledge_base(
                    name=spec["name"],
                    description=spec["description"],
                    roleArn=role_arn,
                    knowledgeBaseConfiguration={
                        "type": "VECTOR",
                        "vectorKnowledgeBaseConfiguration": {
                            "embeddingModelArn": EMBED_MODEL_ARN,
                            # Cohere Embed English v3 defaults to 1024 dims,
                            # matching the S3 Vectors indexes in this stack.
                        },
                    },
                    storageConfiguration={
                        "type": "S3_VECTORS",
                        "s3VectorsConfiguration": {
                            "indexArn": spec["index_arn"],
                        },
                    },
                )
                kb_id = resp["knowledgeBase"]["knowledgeBaseId"]
                print(f"    Created KB: {kb_id}")
            except ClientError as exc:
                print(f"    ERROR creating KB: {exc}")
                return 1

        _wait_kb_active(bedrock_agent, kb_id)
        ds_name = f"{spec['name']}-s3"
        ds_id = _ensure_data_source(bedrock_agent, kb_id, ds_name, spec["prefix"])
        print(f"    Data source: {ds_id}")
        _sync(bedrock_agent, kb_id, ds_id)
        ids[spec["env_key"]] = kb_id
        print()

    _update_env(ids)
    print("Updated src/.env with KB IDs:")
    print(json.dumps(ids, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
