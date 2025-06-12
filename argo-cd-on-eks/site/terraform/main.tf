
terraform {
  required_version = ">= 1.12.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.98.0"
    }
  }
  backend "s3" {
  }
}

provider "aws" {
  region = var.aws_region
}

