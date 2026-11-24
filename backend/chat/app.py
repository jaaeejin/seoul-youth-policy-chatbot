"""POST /chat  (2주차: 배포 확인용 뼈대)

지금 하는 일
  1. 질문에서 주민등록번호·전화번호·이메일 형식을 가린다.
  2. DynamoDB 정책 목록에서 키워드가 겹치는 정책을 찾아 출처 카드로 돌려준다.
  3. 찾지 못하면 추측하지 않고 "등록된 공고에서 찾지 못했다"고 안내한다.
  4. 가린 질문과 응답 시간을 익명 기록으로 저장한다(90일 뒤 TTL 삭제).

3주차 이후: 2번을 S3 Vectors 검색(Titan V2 임베딩) + Bedrock Nova Lite 근거 기반 답변으로 바꾼다.
"""
import json
import os
import re
import time
import uuid

import boto3

ddb = boto3.resource("dynamodb")
POLICIES = ddb.Table(os.environ["POLICIES_TABLE"])
LOGS = ddb.Table(os.environ["CHATLOGS_TABLE"])
TTL_DAYS = int(os.environ.get("LOG_TTL_DAYS", "90"))

PII_PATTERNS = [
    (re.compile(r"\d{6}\s*-\s*[1-4]\d{6}"), "[주민번호]"),
    (re.compile(r"01[016789]-?\d{3,4}-?\d{4}"), "[전화번호]"),
    (re.compile(r"[\w.+-]+@[\w-]+\.[\w.]+"), "[이메일]"),
]


def mask_pii(text: str) -> str:
    for pat, repl in PII_PATTERNS:
        text = pat.sub(repl, text)
    return text


def _resp(status, body):
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json; charset=utf-8"},
        "body": json.dumps(body, ensure_ascii=False, default=str),
    }


def find_policies(question: str, limit: int = 3):
    items = POLICIES.scan().get("Items", [])
    scored = []
    for it in items:
        words = [it.get("name", "")] + list(it.get("keywords", []))
        score = sum(1 for w in words if w and w in question)
        if score:
            scored.append((score, it))
    scored.sort(key=lambda x: -x[0])
    return [it for _, it in scored[:limit]]


def handler(event, context):
    started = time.time()
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _resp(400, {"error": "JSON 형식이 아니에요."})

    question = (body.get("question") or "").strip()
    if not question:
        return _resp(400, {"error": "question 값이 비어 있어요."})
    if len(question) > 500:
        return _resp(400, {"error": "질문은 500자까지 보낼 수 있어요."})

    masked = mask_pii(question)
    hits = find_policies(masked)

    if hits:
        answer = "등록된 공고에서 관련 정책을 찾았어요. 자세한 조건은 출처 카드의 원문에서 확인하세요."
        sources = [
            {
                "no": i + 1,
                "name": h.get("name"),
                "agency": h.get("agency"),
                "year": h.get("year"),
                "deadline": h.get("deadline"),
                "url": h.get("url"),
                "sample": h.get("sample", False),
            }
            for i, h in enumerate(hits)
        ]
    else:
        answer = "등록된 공고에서 근거를 찾지 못했어요. 청년몽땅정보통이나 담당 기관에 문의해 주세요."
        sources = []

    latency_ms = int((time.time() - started) * 1000)
    log_id = str(uuid.uuid4())
    LOGS.put_item(Item={
        "logId": log_id,
        "question": masked,
        "sourceIds": [h.get("policyId") for h in hits],
        "latencyMs": latency_ms,
        "createdAt": int(time.time()),
        "expiresAt": int(time.time()) + TTL_DAYS * 86400,
    })

    return _resp(200, {
        "logId": log_id,
        "question": masked,
        "answer": answer,
        "sources": sources,
        "notice": "최종 자격은 공고 원문과 담당 기관에서 확인하세요.",
        "latencyMs": latency_ms,
    })
