resource "aws_cloudwatch_log_group" "telegram_lambda_loggroup" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 3
}