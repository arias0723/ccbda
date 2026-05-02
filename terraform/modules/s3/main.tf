resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

# resource "aws_s3_bucket_versioning" "lambda_code_bucket_versioning" {
#   bucket = aws_s3_bucket.lambda_code_bucket.id
#
#   versioning {
#     enabled = true
#   }
# }

# resource "aws_s3_bucket_policy" "lambda_code_bucket_policy" {
#   bucket = aws_s3_bucket.lambda_code_bucket.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = "*"
#         Action = "s3:GetObject"
#         Resource = "${aws_s3_bucket.lambda_code_bucket.arn}/*"
#       }
#     ]
#   })
# }