#!/usr/bin/env bash
# 과제가 끝난 뒤 자원 정리. 버킷을 비운 뒤 스택을 지운다.
set -euo pipefail
REGION="${AWS_REGION:-ap-northeast-2}"
STACK="yp-chatbot-dev"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"

empty_bucket() {  # 버전 관리가 켜진 버킷도 비운다
  local b="$1"
  aws s3api head-bucket --bucket "$b" 2>/dev/null || return 0
  python3 - "$b" "$REGION" <<'PY'
import sys, boto3
b = boto3.resource("s3", region_name=sys.argv[2]).Bucket(sys.argv[1])
b.object_versions.delete()
PY
}

empty_bucket "yp-chatbot-docs-${ACCOUNT}-${REGION}"
empty_bucket "yp-chatbot-web-${ACCOUNT}-${REGION}"
aws cloudformation delete-stack --region "$REGION" --stack-name "$STACK"
aws cloudformation wait stack-delete-complete --region "$REGION" --stack-name "$STACK"
empty_bucket "yp-chatbot-artifacts-${ACCOUNT}-${REGION}"
aws s3api delete-bucket --bucket "yp-chatbot-artifacts-${ACCOUNT}-${REGION}" --region "$REGION" || true
echo "정리 끝"
