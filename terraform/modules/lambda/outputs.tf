output "lambda_function_arn" {
  value = aws_lambda_function.telegram_lambda.arn
}

output "lambda_function_url" {
  value = aws_lambda_function_url.telegram_lambda_funtion_url
}