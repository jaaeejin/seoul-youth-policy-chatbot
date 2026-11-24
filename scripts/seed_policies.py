"""예시 정책 목록을 DynamoDB 정책 테이블에 넣는다.

사용: python3 scripts/seed_policies.py <테이블 이름> <JSON 파일> [리전]
"""
import json
import sys

import boto3


def main():
    table_name, path = sys.argv[1], sys.argv[2]
    region = sys.argv[3] if len(sys.argv) > 3 else "ap-northeast-2"
    table = boto3.resource("dynamodb", region_name=region).Table(table_name)
    with open(path, encoding="utf-8") as f:
        items = json.load(f)
    with table.batch_writer() as batch:
        for it in items:
            batch.put_item(Item={k: v for k, v in it.items() if v is not None})
    print(f"{len(items)}건 넣음")


if __name__ == "__main__":
    main()
