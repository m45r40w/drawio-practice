"""GET /items/{id}: DynamoDB から 1 件取得し、結果を S3 に保存して返す。"""
import json
import os
import time

import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
BUCKET_NAME = os.environ["BUCKET_NAME"]

table = boto3.resource("dynamodb").Table(TABLE_NAME)
s3 = boto3.client("s3")


def handler(event, context):
    item_id = (event.get("pathParameters") or {}).get("id")
    if not item_id:
        return _response(400, {"message": "id is required"})

    # ③ DynamoDB からデータ取得 (GetItem)
    item = table.get_item(Key={"id": item_id}).get("Item")
    if item is None:
        _log("item not found", id=item_id)
        return _response(404, {"message": "not found", "id": item_id})

    # ④ S3 にオブジェクト保存 (PutObject)
    key = f"results/{time.strftime('%Y/%m/%d', time.gmtime())}/{context.aws_request_id}.json"
    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=key,
        Body=json.dumps(item, ensure_ascii=False, default=str).encode("utf-8"),
        ContentType="application/json",
    )

    # ⑤ CloudWatch Logs へログ出力（print の内容がログになる）
    _log("item saved", id=item_id, s3_key=key)
    return _response(200, {"item": item, "saved_to": f"s3://{BUCKET_NAME}/{key}"})


def _log(message, **fields):
    print(json.dumps({"message": message, **fields}, ensure_ascii=False))


def _response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json; charset=utf-8"},
        "body": json.dumps(body, ensure_ascii=False, default=str),
    }
