
output "rhelapache_private_ip_address" {
  value = one(azurerm_network_interface.rhelapache.ip_configuration).private_ip_address
}

output "windowsiis_private_ip_address" {
  value = one(azurerm_network_interface.windowsiis.ip_configuration).private_ip_address
}

