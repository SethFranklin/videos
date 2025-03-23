
variable "aws_key_pair_name" {
  description = "The name of the AWS EC2 key pair to use for the AWS EC2 instance"
  type = string
}

variable "azure_key_pair_name" {
  description = "The name of the Azure SSH key pair to use for the Azure VM"
  type = string
}

variable "azure_key_pair_resource_group_name" {
  description = "The name of the resource group that contains Azure SSH key pair to use for the Azure VM"
  type = string
}

