output "api_endpoint" {
  description = "API のURL。例: <api_endpoint>/items/<id>"
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.items.name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.results.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.api.function_name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.lambda.name
}
