#!/usr/bin/env bash
# 개발 · 실행 환경 점검 (CloudShell에서 실행). 보고서의 "환경 확인" 화면용
export LANG=C.UTF-8 LC_ALL=C.UTF-8
REGION="${AWS_REGION:-ap-northeast-2}"
STACK="yp-chatbot-dev"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"

echo "## 도구"
aws --version 2>&1; python3 --version; git --version
echo
echo "## 계정 · 리전"
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output table
echo "region = ${REGION}"
echo
echo "## 스택 상태 · 자원 수 (${STACK})"
echo "$(aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" --query 'Stacks[0].StackStatus' --output text)" \
  "resources=$(aws cloudformation list-stack-resources --stack-name "$STACK" --region "$REGION" --query 'length(StackResourceSummaries)' --output text)"
echo
echo "## 벡터 인덱스 (S3 Vectors)"
aws s3vectors get-index --vector-bucket-name "yp-chatbot-vectors-${ACCOUNT}" --index-name policy-chunks --region "$REGION" \
  --query 'index.[indexName,dimension,distanceMetric]' --output text 2>&1
echo
echo "## Bedrock 모델 (이 프로젝트가 쓰는 임베딩 · 생성 모델)"
aws bedrock list-foundation-models --region "$REGION" \
  --query "modelSummaries[?modelId=='amazon.titan-embed-text-v2:0' || modelId=='amazon.nova-lite-v1:0'].[modelId,modelLifecycle.status,join(',',inferenceTypesSupported)]" \
  --output table
aws bedrock get-inference-profile --inference-profile-identifier apac.amazon.nova-lite-v1:0 --region "$REGION" \
  --query '[inferenceProfileId,status]' --output text
