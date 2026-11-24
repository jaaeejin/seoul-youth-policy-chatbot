# 서울 청년정책 안내 챗봇

서울에 사는 대학생·사회초년생이 청년 지원 정책을 물으면, 정부·서울시 공고문을 근거로 지원 대상·지원 내용·신청 방법을 답하고 원문 출처를 함께 보여주는 RAG 챗봇입니다.
한양대학교 클라우드 아키텍처 과제 (2022066453 이재진).

## 구조

```
CloudFront ─ S3(웹 화면, 비공개 · OAC)
    │
API Gateway (HTTP API, 초당 10건 · 순간 20건 제한)
    ├─ GET  /health    ─┐
    ├─ GET  /policies  ─┴ Lambda policies ─ DynamoDB 정책 목록
    └─ POST /chat      ── Lambda chat ───── DynamoDB 정책 목록(읽기) · 대화 기록(쓰기, TTL 90일)
                                     └ (3주차~) S3 Vectors 검색 · Bedrock 답변
S3 문서 버킷 raw/ · processed/ (버전 관리, KMS 암호화, 퍼블릭 차단)
```

| 폴더 | 내용 |
|---|---|
| `infra/template.yaml` | CloudFormation 템플릿 (S3, CloudFront, DynamoDB, IAM 역할, Lambda, API Gateway, 로그 그룹) |
| `backend/policies` | `/health`, `/policies` Lambda |
| `backend/chat` | `/chat` Lambda (개인정보 가림 → 정책 찾기 → 출처 카드 → 익명 기록) |
| `frontend/` | 배포 확인용 웹 화면 |
| `data/sample_policies.json` | 예시 정책 5건 (화면에 "예시 문서"로 표시) |
| `scripts/` | 배포 · 데이터 넣기 · 정리 스크립트 |
| `tests/` | AWS 없이 도는 단위 테스트 |

## 배포 (AWS CloudShell, 서울 리전)

```bash
git clone https://github.com/jaaeejin/seoul-youth-policy-chatbot.git
cd seoul-youth-policy-chatbot
bash scripts/deploy.sh
```

끝나면 API 주소와 웹 주소가 출력되고, `/health`와 `/chat` 호출 결과까지 보여 줍니다.

## 정리

```bash
bash scripts/destroy.sh
```

## 테스트

```bash
python tests/test_logic.py
```

## 주차별 진행

- [x] 1주차: 서비스 기획 · 아키텍처 설계
- [x] 2주차: AWS 기본 환경 · 개발 환경 · 테스트 API 배포
- [ ] 3주차~: 문서 수집 · 분할 · 임베딩(Bedrock Cohere Embed v4) · S3 Vectors 적재, Claude 근거 기반 답변
