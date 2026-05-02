output "lambda_function_arn" {
  value = module.lambda.lambda_function_arn
}

output "lambda_function_url" {
  value = module.lambda.lambda_function_url
}

output "s3_bucket_name" {
  value = module.s3.s3_bucket_name
}