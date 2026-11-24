# CLAUDE.md

Claude Code가 이 저장소에서 작업할 때 지키는 규칙.

- 리전은 서울(ap-northeast-2). 모델은 Titan Text Embeddings V2(임베딩)와 Nova Lite(생성)로 고정하고, 더 비싼 모델은 쓰지 않는다. 인프라 변경은 `infra/template.yaml`에만 하고, 콘솔에서 손으로 만든 자원은 템플릿에 옮겨 적는다.
- IAM 정책은 함수별 최소 권한. `*` 리소스나 `AdministratorAccess`를 붙이지 않는다.
- 액세스 키 · 비밀번호 · `.env`는 커밋하지 않는다. 배포는 CloudShell의 콘솔 자격 증명으로 한다.
- 답변은 등록된 공고 조각에서만 만든다. 근거가 없으면 "등록된 공고에서 찾지 못했다"고 답한다.
- 사용자 개인정보는 저장하지 않는다. 질문은 가린 뒤에만 기록하고, 기록은 TTL 90일.
- 예시 데이터는 `sample: true`로 두고 화면에 "예시 문서"로 표시한다.
- 코드를 바꾸면 `python tests/test_logic.py`를 돌린다.
