# Lambda Module README

# Lambda Module

This module is responsible for creating an AWS Lambda function along with the necessary IAM roles and permissions. It allows for easy deployment and management of Lambda functions within your Terraform configuration.

## Usage

```hcl
module "lambda" {
  source = "./modules/lambda"

  # Required variables
  lambdasVersion = var.lambdasVersion

  # Additional optional variables can be added here
}
```

## Inputs

| Name            | Description                                   | Type   | Default | Required |
|-----------------|-----------------------------------------------|--------|---------|:--------:|
| lambdasVersion  | Version of the Lambda function zip on S3     | string | n/a     |   yes    |

## Outputs

| Name                | Description                                   |
|---------------------|-----------------------------------------------|
| lambda_function_arn | The ARN of the created Lambda function        |
| lambda_function_url | The URL of the created Lambda function URL    |
