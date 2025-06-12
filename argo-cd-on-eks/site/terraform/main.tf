
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

locals {
  VPC_ADDRESS_SPACE = "10.0.0.0/16"
  AVAILABILITY_ZONES = ["a", "b", "c"]

  subnet_prefix_new_bits = ceil(log(length(local.AVAILABILITY_ZONES), 2))
  subnet_address_spaces = cidrsubnets(local.VPC_ADDRESS_SPACE, [ for az in local.AVAILABILITY_ZONES : local.subnet_prefix_new_bits ]...)
}

resource "aws_vpc" "argo_cd" {
  cidr_block = local.VPC_ADDRESS_SPACE

  tags = {
    name = "Argo CD VPC"
  }
}

resource "aws_subnet" "argo_cd" {
  for_each = toset(local.AVAILABILITY_ZONES)

  vpc_id     = aws_vpc.argo_cd.id
  cidr_block = local.subnet_address_spaces[index(local.AVAILABILITY_ZONES, each.key)]
  availability_zone = "${var.aws_region}${each.key}"

  tags = {
    Name = "Argo CD Subnet AZ ${each.key}"
  }
}

