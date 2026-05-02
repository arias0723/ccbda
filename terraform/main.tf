module "s3" {
  source = "./modules/s3"
  bucket_name = var.bucket_name
}

module "iam" {
  source = "./modules/iam"
  lambda_role_name = var.lambda_role_name
}

module "lambda" {
  source = "./modules/lambda"
  lambda_version = var.lambda_version
  function_name = var.lambda_function_name
  lambda_role_arn = module.iam.lambda_role_arn

#   s3_bucket_name = module.s3.bucket_name
#   environment = {
#     TELEGRAM_TOKEN = var.telegram_token
#   }
}