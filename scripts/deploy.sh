#!/usr/bin/env bash
# AWS CloudShell(서울 리전)에서 실행:
#   git clone https://github.com/jaaeejin/seoul-youth-policy-chatbot.git
#   cd seoul-youth-policy-chatbot && bash scripts/deploy.sh
set -euo pipefail
# CloudShell 기본 로캘에서는 템플릿 한글이 ??로 깨지므로 UTF-8로 읽게 한다
export AWS_CLI_FILE_ENCODING=UTF-8 LANG=C.UTF-8 LC_ALL=C.UTF-8 PYTHONUTF8=1

REGION="${AWS_REGION:-ap-northeast-2}"
PROJECT="yp-chatbot"
STAGE="dev"
STACK="${PROJECT}-${STAGE}"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
ARTIFACTS="${PROJECT}-artifacts-${ACCOUNT}-${REGION}"

cd "$(dirname "$0")/.."

echo "== 1. 배포 파일 버킷 준비: ${ARTIFACTS}"
if ! aws s3api head-bucket --bucket "$ARTIFACTS" 2>/dev/null; then
  aws s3api create-bucket --bucket "$ARTIFACTS" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" >/dev/null
  aws s3api put-public-access-block --bucket "$ARTIFACTS" \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
fi

echo "== 2. Lambda 코드 패키징"
aws cloudformation package --region "$REGION" \
  --template-file infra/template.yaml \
  --s3-bucket "$ARTIFACTS" --s3-prefix lambda \
  --output-template-file /tmp/packaged.yaml >/dev/null

echo "== 3. CloudFormation 배포: ${STACK} (CloudFront 생성에 몇 분 걸림)"
aws cloudformation deploy --region "$REGION" \
  --template-file /tmp/packaged.yaml --stack-name "$STACK" \
  --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset

out() { aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
API_URL="$(out ApiUrl)"; WEB_URL="$(out WebUrl)"; WEB_BUCKET="$(out WebBucketName)"
DIST_ID="$(out DistributionId)"; DOCS_BUCKET="$(out DocsBucketName)"; TABLE="$(out PoliciesTableName)"

echo "== 4. 예시 정책 데이터 넣기 → ${TABLE}"
python3 scripts/seed_policies.py "$TABLE" data/sample_policies.json "$REGION"

echo "== 5. 문서 버킷 폴더(raw/ · processed/) 만들기"
aws s3api put-object --bucket "$DOCS_BUCKET" --key raw/ >/dev/null
aws s3api put-object --bucket "$DOCS_BUCKET" --key processed/ >/dev/null

echo "== 5-1. 벡터 저장소(S3 Vectors) 만들기 — 3주차 적재용 빈 인덱스"
VBUCKET="${PROJECT}-vectors-${ACCOUNT}"
if aws s3vectors get-vector-bucket --vector-bucket-name "$VBUCKET" --region "$REGION" >/dev/null 2>&1; then
  echo "이미 있음: ${VBUCKET}"
elif aws s3vectors create-vector-bucket --vector-bucket-name "$VBUCKET" --region "$REGION" >/dev/null 2>&1; then
  # Cohere Embed v4 기본 차원 1536, 코사인 거리. 원문 조각은 검색 필터에 쓰지 않는 메타데이터로 둔다
  aws s3vectors create-index --vector-bucket-name "$VBUCKET" --index-name policy-chunks \
    --data-type float32 --dimension 1536 --distance-metric cosine \
    --metadata-configuration '{"nonFilterableMetadataKeys":["text"]}' --region "$REGION" >/dev/null
  echo "만듦: ${VBUCKET}/policy-chunks"
else
  echo "S3 Vectors를 만들지 못함(리전·CLI 버전 확인 필요). 다음 단계로 넘어감"
fi

echo "== 6. 웹 화면 올리기 → ${WEB_BUCKET}"
printf 'window.APP_CONFIG = { apiUrl: "%s" };\n' "$API_URL" > /tmp/config.js
aws s3 cp frontend/index.html "s3://${WEB_BUCKET}/index.html" --content-type "text/html; charset=utf-8" >/dev/null
aws s3 cp /tmp/config.js "s3://${WEB_BUCKET}/config.js" --content-type "application/javascript" --cache-control "no-cache" >/dev/null
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" >/dev/null

echo
echo "API  : ${API_URL}"
echo "WEB  : ${WEB_URL}"
echo
echo "== 7. 동작 확인"
curl -s "${API_URL}/health"; echo
curl -s -X POST "${API_URL}/chat" -H 'content-type: application/json' \
  -d '{"question":"자취 시작하는데 월세 지원 있어? 내 번호는 010-1234-5678"}'; echo
