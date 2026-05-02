variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket to create."
}

# variable "bucket_region" {
#   type        = string
#   description = "The AWS region where the S3 bucket will be created."
# }
#
# variable "versioning_enabled" {
#   type        = bool
#   description = "Enable versioning for the S3 bucket."
#   default     = false
# }

# variable "lifecycle_rules" {
#   type        = list(object({
#     id      = string
#     enabled = bool
#     prefix  = string
#     expiration {
#       days = number
#     }
#   # Prevent deletion
#   lifecycle {
#     prevent_destroy = true
#   }
#   }))
#   description = "Lifecycle rules for managing objects in the S3 bucket."
#   default     = []
# }