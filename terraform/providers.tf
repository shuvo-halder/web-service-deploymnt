terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "devops-task-tf-state"       # Change to your S3 bucket name
    key            = "env/terraform.tfstate"
    region         = "ap-southeast-1"             # Change to your preferred region
    dynamodb_table = "terraform-state-lock"       # Required for state locking
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}