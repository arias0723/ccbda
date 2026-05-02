output "s3_bucket_name" {
  value = aws_s3_bucket.lambda_code_bucket.bucket
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.lambda_code_bucket.arn
}