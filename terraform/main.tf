# See https://terrateam.io/blog/aws-lambda-function-with-terraform

# Simple AWS Lambda Terraform
# Test: run `terraform plan`
# Deploy: run `terraform apply`
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.47.0"
    }
  }
  backend "s3" {
    bucket = "bucket-for-terraform-state-telegram-lambda"
    key    = "my_lambda/terraform.tfstate"
    region = "eu-north-1"
  }
}

provider "aws" {
  region = "eu-north-1"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "bucket-for-terraform-state-python-lambda"
  # Prevent deletion
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role" "telegram_lambda_role" {
  name               = "telegram_lambda-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

data "archive_file" "python_lambda_package" {
  type = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/../dist/telegram_lambda_${var.lambdasVersion}.zip"
}

resource "aws_lambda_function" "telegram_lambda" {
  filename       = "${path.module}/../dist/telegram_lambda_${var.lambdasVersion}.zip"
  function_name = "telegram_lambda"
  handler       = "lambda_function.lambda_handler"

  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
  role          = aws_iam_role.telegram_lambda_role.arn
  runtime       = "python3.9"
  memory_size   = 1024
  timeout       = 10
}

resource "aws_cloudwatch_log_group" "telegram_lambda_loggroup" {
  name              = "/aws/lambda/${aws_lambda_function.telegram_lambda.function_name}"
  retention_in_days = 3
}

data "aws_iam_policy_document" "telegram_lambda_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      aws_cloudwatch_log_group.telegram_lambda_loggroup.arn,
      "${aws_cloudwatch_log_group.telegram_lambda_loggroup.arn}:*"
    ]
  }
}

resource "aws_iam_role_policy" "telegram_lambda_role_policy" {
  policy = data.aws_iam_policy_document.telegram_lambda_policy.json
  role   = aws_iam_role.telegram_lambda_role.id
  name   = "telegram-lambda-policy"
}

resource "aws_lambda_function_url" "telegram_lambda_funtion_url" {
  function_name      = aws_lambda_function.telegram_lambda.id
  authorization_type = "NONE"
  cors {
    allow_origins = ["*"]
  }
}

resource "aws_lambda_permission" "allow_public_invoke_function_url" {
  statement_id           = "AllowPublicInvokeFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.telegram_lambda.function_name
  principal              = "*"
  function_url_auth_type = "NONE"

  # Ensure the URL exists before attaching URL permission
  depends_on = [aws_lambda_function_url.telegram_lambda_funtion_url]
}

resource "aws_lambda_permission" "allow_public_invoke_function" {
  statement_id  = "AllowPublicInvokeFunction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.telegram_lambda.function_name
  principal     = "*"
}

# output "aws_lambda_url" {
#     value = telegram_lambda_funtion_url.url
# }
