variable "region" {
  type        = string
  description = "AWS region for the resources"
  default     = "eu-north-1"
}

variable "lambda_version" {
  type        = string
  description = "Version of the Lambda zip file on S3"
}

variable "lambda_function_name" {
  type        = string
  description = "Name of the Lambda function"
}

variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket for storing Lambda code"
}

variable "lambda_role_name" {
  type        = string
  description = "Name of the IAM role for the Lambda function"
}
