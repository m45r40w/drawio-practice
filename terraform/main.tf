# 構成図 (aws-serverless.drawio) との対応:
#   ① 利用者 → API Gateway      : aws_apigatewayv2_api / route "GET /items/{id}"
#   ② API Gateway → Lambda       : aws_apigatewayv2_integration + aws_lambda_permission
#   ③ Lambda → DynamoDB (GetItem): aws_dynamodb_table + IAM (dynamodb:GetItem / Query)
#   ④ Lambda → S3 (PutObject)    : aws_s3_bucket + IAM (s3:PutObject)
#   ⑤ Lambda → CloudWatch Logs   : aws_cloudwatch_log_group + IAM (logs:PutLogEvents)

data "aws_caller_identity" "current" {}

locals {
  function_name = "${var.project}-api"
  # S3 バケット名は世界で一意なので、アカウントIDとリージョンを付ける
  bucket_name = "${var.project}-results-${data.aws_caller_identity.current.account_id}-${var.region}"
}

# ---------------------------------------------------------------------------
# ③ Amazon DynamoDB
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "items" {
  name         = "${var.project}-items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}

# ---------------------------------------------------------------------------
# ④ Amazon S3
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "results" {
  bucket        = local.bucket_name
  force_destroy = var.s3_force_destroy
}

resource "aws_s3_bucket_public_access_block" "results" {
  bucket                  = aws_s3_bucket.results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "results" {
  bucket = aws_s3_bucket.results.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "results" {
  bucket = aws_s3_bucket.results.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------------------
# ⑤ Amazon CloudWatch Logs
#   Lambda が自動で作る前に作っておき、保存日数を設定する
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
}

# ---------------------------------------------------------------------------
# AWS Lambda と実行ロール（③④⑤ に必要な権限だけを与える）
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid       = "ReadItems" # ③
    actions   = ["dynamodb:GetItem", "dynamodb:Query"]
    resources = [aws_dynamodb_table.items.arn]
  }

  statement {
    sid       = "PutResults" # ④
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.results.arn}/results/*"]
  }

  statement {
    sid       = "WriteLogs" # ⑤
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${local.function_name}-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/build/lambda.zip"
}

resource "aws_lambda_function" "api" {
  function_name    = local.function_name
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.13"
  handler          = "handler.handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.items.name
      BUCKET_NAME = aws_s3_bucket.results.bucket
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.lambda.name
  }

  depends_on = [aws_iam_role_policy.lambda]
}

# ---------------------------------------------------------------------------
# ①② Amazon API Gateway (HTTP API)
# ---------------------------------------------------------------------------
resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project}-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_item" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

# API Gateway が Lambda を呼べるようにする（このルートからだけ）
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowInvokeFromHttpApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/GET/items/{id}"
}
