"""GET /health, GET /policies

/health   : 배포 확인용. 리전·시각·정책 테이블 연결 상태를 돌려준다.
/policies : DynamoDB 정책 목록과 신청 기간 상태(모집 중 / 마감 임박 / 마감)를 돌려준다.
"""
import json
import os
from datetime import date, datetime, timezone, timedelta

import boto3

KST = timezone(timedelta(hours=9))
TABLE = boto3.resource("dynamodb").Table(os.environ["POLICIES_TABLE"])


def _resp(status, body):
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json; charset=utf-8"},
        "body": json.dumps(body, ensure_ascii=False, default=str),
    }


def deadline_status(deadline: str | None, today: date) -> str:
    """신청 마감일로 모집 상태를 정한다. 마감일이 없으면 상시."""
    if not deadline:
        return "상시"
    d = date.fromisoformat(deadline)
    if d < today:
        return "마감"
    if (d - today).days <= 7:
        return "마감 임박"
    return "모집 중"


def handler(event, context):
    path = event.get("rawPath", "")
    today = datetime.now(KST).date()

    if path.endswith("/health"):
        try:
            count = TABLE.scan(Select="COUNT")["Count"]
            db = "ok"
        except Exception as e:  # 테이블 연결 실패도 그대로 보여준다
            count, db = None, f"error: {type(e).__name__}"
        return _resp(200, {
            "service": "seoul-youth-policy-chatbot",
            "status": "ok",
            "region": os.environ.get("AWS_REGION"),
            "time": datetime.now(KST).isoformat(timespec="seconds"),
            "policiesTable": db,
            "policyCount": count,
        })

    items = TABLE.scan().get("Items", [])
    for it in items:
        it["status"] = deadline_status(it.get("deadline"), today)
    items.sort(key=lambda x: x.get("deadline") or "9999-12-31")
    return _resp(200, {"count": len(items), "policies": items})
