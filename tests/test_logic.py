"""AWS 없이 돌리는 단위 테스트: python -m pytest tests  (또는 python tests/test_logic.py)"""
import importlib.util
import os
import sys
import types
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# boto3 가짜 모듈 (네트워크 없이 import만 되게)
fake = types.ModuleType("boto3")
fake.resource = lambda *a, **k: types.SimpleNamespace(Table=lambda name: None)
sys.modules["boto3"] = fake
os.environ.update(POLICIES_TABLE="t", CHATLOGS_TABLE="t")


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "backend" / name / "app.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


policies = load("policies")
chat = load("chat")


def test_deadline_status():
    today = date(2026, 11, 24)
    assert policies.deadline_status(None, today) == "상시"
    assert policies.deadline_status("2026-11-23", today) == "마감"
    assert policies.deadline_status("2026-11-28", today) == "마감 임박"
    assert policies.deadline_status("2026-12-20", today) == "모집 중"


def test_mask_pii():
    s = chat.mask_pii("내 번호 010-1234-5678, 주민번호 990101-1234567, a.b@c.com")
    assert "010" not in s and "990101" not in s and "@" not in s
    assert "[전화번호]" in s and "[주민번호]" in s and "[이메일]" in s


if __name__ == "__main__":
    test_deadline_status()
    test_mask_pii()
    print("ok")
