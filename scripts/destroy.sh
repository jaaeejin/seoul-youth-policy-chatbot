#!/usr/bin/env bash
# 과제가 끝난 뒤 자원 정리. 버킷을 비운 뒤 스택을 지운다.
set -euo pipefail
REGION="${AWS_REGION:-ap-northeast-2}"
STACK="yp-chatbot-dev"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"

empty_bucket() {  # 버전 관리가 켜진 버킷도 비운다
  local b="$1"
  aws s3api head-bucket --bucket "$b" >/dev/null 2>&1 || return 0
  python3 - "$b" "$REGION" <<'PY'
import sys, boto3
b = boto3.resource("s3", region_name=sys.argv[2]).Bucket(sys.argv[1])
b.object_versions.delete()
PY
}

VBUCKET="yp-chatbot-vectors-${ACCOUNT}"
aws s3vectors delete-index --vector-bucket-name "$VBUCKET" --index-name policy-chunks --region "$REGION" 2>/dev/null || true
aws s3vectors delete-vector-bucket --vector-bucket-name "$VBUCKET" --region "$REGION" 2>/dev/null || true

empty_bucket "yp-chatbot-docs-${ACCOUNT}-${REGION}"
empty_bucket "yp-chatbot-web-${ACCOUNT}-${REGION}"
aws cloudformation delete-stack --region "$REGION" --stack-name "$STACK"
aws cloudformation wait stack-delete-complete --region "$REGION" --stack-name "$STACK"
empty_bucket "yp-chatbot-artifacts-${ACCOUNT}-${REGION}"
aws s3api delete-bucket --bucket "yp-chatbot-artifacts-${ACCOUNT}-${REGION}" --region "$REGION" || true
echo "정리 끝"
