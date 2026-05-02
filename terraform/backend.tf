terraform {
  backend "s3" {
    bucket = "bucket-for-terraform-state-telegram-lambda"
    key    = "my_lambda/terraform.tfstate"
    region = "eu-north-1"
  }
}