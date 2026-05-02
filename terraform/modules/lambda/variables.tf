variable "lambda_version" {
  type        = string
  description = "Version of the Lambda zip file on S3"
}

variable "function_name" {
  type        = string
  description = "The name of the Lambda function."
}

# variable "handler" {
#   type        = string
#   description = "The handler for the Lambda function."
# }
#
# variable "runtime" {
#   type        = string
#   description = "The runtime environment for the Lambda function."
# }
#
# variable "memory_size" {
#   type        = number
#   description = "The amount of memory available to the Lambda function."
#   default     = 1024
# }
#
# variable "timeout" {
#   type        = number
#   description = "The amount of time in seconds that the function can run before timing out."
#   default     = 10
# }
#
# variable "source_code_hash" {
#   type        = string
#   description = "The base64-encoded SHA256 hash of the function's deployment package."
# }
#
variable "lambda_role_arn" {
  type        = string
  description = "The ARN of the IAM role that the Lambda function assumes."
}