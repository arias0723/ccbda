# Project Overview

This project is designed to deploy an AWS Lambda function that interacts with the Telegram Bot API. It utilizes Terraform for infrastructure as code, allowing for easy management and deployment of AWS resources.

## Project Structure

The project is organized into the following directories and files:

- **terraform/**: Contains all Terraform configuration files and modules.
  - **backend.tf**: Configuration for the S3 backend to store Terraform state.
  - **providers.tf**: Defines the required providers for the project.
  - **main.tf**: Main entry point for the Terraform configuration.
  - **variables.tf**: Input variables for the Terraform configuration.
  - **outputs.tf**: Outputs of the Terraform configuration.
  - **deploy.sh**: Shell script to automate the deployment process.
  - **.terraform.lock.hcl**: Automatically generated file to lock provider versions.
  - **modules/**: Contains reusable Terraform modules.
    - **lambda/**: Module for the Lambda function.
      - **main.tf**: Resources related to the Lambda function.
      - **variables.tf**: Input variables for the Lambda module.
      - **outputs.tf**: Outputs for the Lambda module.
      - **README.md**: Documentation for the Lambda module.
    - **iam/**: Module for IAM roles and policies.
      - **main.tf**: IAM resources for the Lambda function.
      - **variables.tf**: Input variables for the IAM module.
      - **outputs.tf**: Outputs for the IAM module.
      - **README.md**: Documentation for the IAM module.
    - **s3/**: Module for S3 bucket resources.
      - **main.tf**: S3 resources for storing Lambda code and Terraform state.
      - **variables.tf**: Input variables for the S3 module.
      - **outputs.tf**: Outputs for the S3 module.
      - **README.md**: Documentation for the S3 module.

- **lambda/**: Contains the Lambda function code and dependencies.
  - **lambda_function.py**: Python code for the Lambda function.
  - **requirements.txt**: Python dependencies required for the Lambda function.

- **README.md**: This file provides an overview of the project, setup instructions, and usage.

- **LICENSE**: Licensing information for the project.

- **.gitignore**: Specifies files and directories to be ignored by Git.

## Setup Instructions

1. **Clone the Repository**: Clone this repository to your local machine.
   
2. **Install Dependencies**: Navigate to the `lambda` directory and install the required Python packages:
   ```
   pip install -r requirements.txt
   ```

3. **Configure AWS Credentials**: Ensure that your AWS credentials are configured. You can do this by setting up the AWS CLI or using environment variables.

4. **Initialize Terraform**: Navigate to the `terraform` directory and run:
   ```
   terraform init
   ```

5. **Plan the Deployment**: Run the following command to see what resources will be created:
   ```
   terraform plan
   ```

6. **Deploy the Infrastructure**: Apply the Terraform configuration to deploy the resources:
   ```
   terraform apply
   ```

## Usage

Once deployed, the Lambda function will be accessible via the configured API Gateway. You can set up a webhook with your Telegram bot to point to the Lambda function URL.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.