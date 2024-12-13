# Part 1 - AWS DynamoDB
resource "aws_dynamodb_table" "cloud_resume" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "PageId"

  attribute {
    name = "PageId"
    type = "S"
  }

  attribute {
    name = "ViewCount"
    type = "S"
  }
}

# Part 2 - AWS S3 for storing Lambda funciton zip archive
resource "aws_s3_bucket" "cloud_resume_lambda_bucket" {
  # Define the name of the bucket
  bucket = "cloud_resume_lambda"
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
  name = "RoleForCloudResumeLambda"

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
  policy = data.aws_iam_policy_document.allow_update_dynamodb

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
