variable "aws_region" {
  type        = string
  default     = "us-west-2"
  description = "AWS region for all resources."
}

variable "dynamodb_table_name" {
  type        = string
  default     = "Cloud_Resume"
  description = "Name of the DynamoDB table."
}

variable "email" {
  type        = string
  default     = "jimmytan0424@gmail.com"
  description = "Email to receive notification."
}
