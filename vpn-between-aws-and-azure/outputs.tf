
output "azure_jumpbox_public_ip_address" {
  description = "The public ip address of the Azure jumpbox VM"
  value       = azurerm_public_ip.jumpbox.ip_address
}

