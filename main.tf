# Part 1 - AWS DynamoDB
resource "aws_dynamodb_table" "cloud_resume" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "PageId"

  attribute {
    name = "PageId"
    type = "S"
  }
}

# Part 2 - AWS S3 for storing Lambda funciton zip archive
resource "aws_s3_bucket" "cloud_resume_lambda_bucket" {
  # Define the name of the bucket
  bucket = "cloud-resume-lambda-code-bucket"
}

resource "aws_s3_bucket_ownership_controls" "cloud_resume_lambda_bucket" {
  # Name of the bucket that you want to associate this access point with.
  bucket = aws_s3_bucket.cloud_resume_lambda_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "lambda_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.cloud_resume_lambda_bucket]

  bucket = aws_s3_bucket.cloud_resume_lambda_bucket.id
  acl    = "private" # Private ACL
}

# Generate a zip archive for lambda function
data "archive_file" "lambda_update_count" {
  type = "zip"

  # Package entire contents of this directory into the archive.
  source_dir = "${path.module}/lambda-function"

  output_path = "${path.module}/lambda-function.zip"
}

# Upload the archive to the S3 bucket
resource "aws_s3_object" "cloud_resume_lambda_object" {
  bucket = aws_s3_bucket.cloud_resume_lambda_bucket.id

  # Name of the object once it is in the bucket
  key = "updateCountLambdaFunction.zip"

  # Path to a file that will be read and uploaded as raw bytes for the object content.
  source = data.archive_file.lambda_update_count.output_path

  # Triggers updates when the value changes.
  etag = filemd5(data.archive_file.lambda_update_count.output_path)
}

# Part 3 - Create AWS Lambda function

# Create an IAM role for the lambda function
resource "aws_iam_role" "lambda_exec" {
  name        = "RoleForCloudResumeLambda"
  description = "Role for Lambda function to have access to DynamoDB"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

# Attach policy to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_policy_1" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

// Create inline policy for the IAM role
resource "aws_iam_role_policy" "lambda_policy_2" {
  role = aws_iam_role.lambda_exec.name

  name = "ResumeDynamoDBWriteAccess"

  # The inline policy document
  policy = data.aws_iam_policy_document.allow_update_dynamodb.json

}

data "aws_iam_policy_document" "allow_update_dynamodb" {
  version = "2012-10-17"

  statement {
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
    ]
    resources = [
      aws_dynamodb_table.cloud_resume.arn
    ]
  }
}

// Create function
resource "aws_lambda_function" "cloud_resume_lambda" {
  function_name = "UpdateResumeViewCount"

  # Import function from S3
  s3_bucket = aws_s3_bucket.cloud_resume_lambda_bucket.id
  s3_key    = aws_s3_object.cloud_resume_lambda_object.key

  runtime = "nodejs22.x"
  handler = "updateCount.handler" # Function entrypoint in your code

  # The source_code_hash attribute will change whenever you update the code contained in the archive, which lets Lambda know that there is a new version of your code available.
  source_code_hash = data.archive_file.lambda_update_count.output_base64sha256

  # Amazon Resource Name (ARN) of the function's execution role. The role provides the function's identity and access to AWS services and resources.
  role = aws_iam_role.lambda_exec.arn
}

# Set up log group
resource "aws_cloudwatch_log_group" "update_count" {
  name = "/aws/lambda/${aws_lambda_function.cloud_resume_lambda.function_name}"

  retention_in_days = 30
}

# Part 4 - Create AWS API Gateway

# Defines a name for the API Gateway and sets its protocol to HTTP.
resource "aws_apigatewayv2_api" "lambda" {
  name          = "ViewCountAPI"
  protocol_type = "HTTP"

  # CORS configs
  cors_configuration {
    allow_credentials = false
    allow_methods = [
      "OPTIONS",
      "POST",
    ]
    allow_origins = [
      "http://localhost:5173",
      "https://resume.jimtan.ca"
    ]
    allow_headers = [
      "Content-Type",
    ]
  }
}

# Configures the API Gateway to use your Lambda function.
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id = aws_apigatewayv2_api.lambda.id

  # URI of the Lambda function for a Lambda proxy integration
  integration_uri    = aws_lambda_function.cloud_resume_lambda.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

# Configure routes
resource "aws_apigatewayv2_route" "update_count_route" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /update-view-count" # POST to {invoke_url}/update-view-count
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Sets up application stages
resource "aws_apigatewayv2_stage" "api_stage" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "test"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 500  # Number of requests the API can handle concurrently
    throttling_rate_limit  = 1000 # Number of allowed requests per second
  }

  # Access logging enabled
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.resume_api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

# Create a log group in CloudWatch
resource "aws_cloudwatch_log_group" "resume_api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

# Permission to invoke the Lambda function
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloud_resume_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
