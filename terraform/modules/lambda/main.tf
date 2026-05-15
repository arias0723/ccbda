resource "aws_lambda_function" "telegram_lambda" {
  filename       = "${path.root}/../dist/telegram_lambda_${var.lambda_version}.zip"
  function_name  = var.function_name

  handler        = "lambda_function.lambda_handler"
  role           = var.lambda_role_arn
  runtime        = "python3.12"
  memory_size    = 1024
  timeout        = 30            # Increased timeout: fetching tools + bedrock + tool call can take 10+ seconds

  # This ensures terraform realizes when the zip file has been updated
  source_code_hash = filebase64sha256("${path.root}/../dist/telegram_lambda_${var.lambda_version}.zip")
}

## Lambda invoke

resource "aws_lambda_permission" "allow_public_invoke" {
  statement_id  = "AllowPublicInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.telegram_lambda.function_name
  principal     = "*"
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