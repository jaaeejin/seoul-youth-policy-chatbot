#!/usr/bin/env bash
# 개발 · 실행 환경 점검 (CloudShell에서 실행). 보고서의 "환경 확인" 화면용
export AWS_CLI_FILE_ENCODING=UTF-8 LANG=C.UTF-8 LC_ALL=C.UTF-8
REGION="${AWS_REGION:-ap-northeast-2}"
STACK="yp-chatbot-dev"

echo "## 도구"
aws --version 2>&1; python3 --version; git --version
echo
echo "## 계정 · 리전"
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output table
echo "region = ${REGION}"
echo
echo "## 스택 자원 (${STACK})"
aws cloudformation list-stack-resources --stack-name "$STACK" --region "$REGION" \
  --query 'StackResourceSummaries[].[ResourceType,LogicalResourceId,ResourceStatus]' --output table
echo
echo "## 벡터 저장소 (S3 Vectors)"
aws s3vectors list-indexes --vector-bucket-name "yp-chatbot-vectors-$(aws sts get-caller-identity --query Account --output text)" \
  --region "$REGION" --query 'indexes[].indexName' --output text 2>&1
echo
echo "## Bedrock 모델 (서울 리전에서 쓸 수 있는 임베딩 · 생성 모델)"
aws bedrock list-foundation-models --region "$REGION" \
  --query "modelSummaries[?contains(modelId,'cohere.embed') || contains(modelId,'titan-embed-text-v2') || contains(modelId,'anthropic.claude')].[modelId,modelLifecycle.status]" \
  --output table
