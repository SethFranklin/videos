
output "azure_jumpbox_public_ip_address" {
  description = "The public ip address of the Azure jumpbox VM"
  value       = azurerm_public_ip.jumpbox.ip_address
}

output "aws_jumpbox_elastic_ip_address" {
  description = "The elastic ip address of the AWS jumpbox EC2 instance"
  value       = aws_eip.jumpbox.public_ip
}

