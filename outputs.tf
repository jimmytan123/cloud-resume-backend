output "cloud_resume_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.cloud_resume.name
}

output "cloud_resume_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.cloud_resume.arn
}

output "lambda_bucket_name" {
  description = "Name of the S3 bucket used to store lambda function code"
  value       = aws_s3_bucket.cloud_resume_lambda_bucket.id
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.cloud_resume_lambda.function_name
}

output "base_url" {
  description = "Base URL for API Gateway stage"
  value       = aws_apigatewayv2_stage.api_stage.invoke_url
}