# IAM Module

This module is responsible for creating the necessary IAM roles and policies required for the Lambda function to operate securely.

## Usage

```hcl
module "iam" {
  source = "./modules/iam"

  # Input variables
  lambda_role_name = "your_lambda_role_name"
}
```

## Input Variables

| Name       | Description                             | Type   | Default | Required |
|------------|-----------------------------------------|--------|---------|----------|
| lambda_role_name  | The name of the IAM role to create.    | string | n/a     | yes      |

## Outputs

| Name            | Description                          |
|-----------------|--------------------------------------|
| lambda_role_arn | The ARN of the created IAM role.     |
