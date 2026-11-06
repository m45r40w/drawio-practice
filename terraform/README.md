# Terraform（構成図のコード化）

`../aws-serverless.drawio` の構成を Terraform で表したものです。

| 図 | リソース |
| --- | --- |
| ① 利用者 → API Gateway | `aws_apigatewayv2_api`（HTTP API）、ルート `GET /items/{id}` |
| ② API Gateway → Lambda | `aws_apigatewayv2_integration`、`aws_lambda_permission` |
| ③ Lambda → DynamoDB（GetItem） | `aws_dynamodb_table`（キー `id`）、IAM で `dynamodb:GetItem` / `Query` |
| ④ Lambda → S3（PutObject） | `aws_s3_bucket`（非公開・暗号化）、IAM で `results/*` への `s3:PutObject` |
| ⑤ Lambda → CloudWatch Logs | `aws_cloudwatch_log_group`（保存 14 日）、IAM で `logs:PutLogEvents` |
| Region | `var.region`（既定 `ap-northeast-1`） |

Lambda（`lambda/handler.py`）は、DynamoDB から `id` で 1 件取得し、結果を S3 の `results/YYYY/MM/DD/<リクエストID>.json` に保存して返します。

## 使い方

AWS の認証情報を設定してから実行します。

```bash
terraform init
```

```bash
terraform plan
```

```bash
terraform apply
```

動作確認（データを 1 件入れて API を呼ぶ）:

```bash
aws dynamodb put-item --table-name "$(terraform output -raw dynamodb_table_name)" --item '{"id":{"S":"a1"},"name":{"S":"りんご"}}'
```

```bash
curl "$(terraform output -raw api_endpoint)/items/a1"
```

片付け（S3 に結果が残っていると失敗します。練習用なら `-var s3_force_destroy=true` で apply してから destroy）:

```bash
terraform destroy
```

## 注意

- API に認証はありません。URL を知っていれば誰でも呼べるので、練習が終わったら destroy してください。
- state はローカル（`terraform.tfstate`）に保存されます。チームで使うなら S3 などの backend を設定してください。
