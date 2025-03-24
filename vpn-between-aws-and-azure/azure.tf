
provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}

locals {
  AZURE_LOCATION      = "East US"
  AZURE_ADDRESS_SPACE = "10.0.0.0/24"
}

resource "azurerm_resource_group" "vpn" {
  name     = "vpn"
  location = local.AZURE_LOCATION
}

resource "azurerm_virtual_network" "vpn" {
  name                = "vpn_vnet"
  resource_group_name = azurerm_resource_group.vpn.name
  location            = azurerm_resource_group.vpn.location
  address_space       = [local.AZURE_ADDRESS_SPACE]
}

resource "azurerm_subnet" "vpn" {
  name                 = "vpn_subnet"
  resource_group_name  = azurerm_resource_group.vpn.name
  virtual_network_name = azurerm_virtual_network.vpn.name
  address_prefixes     = [local.AZURE_ADDRESS_SPACE]
}

resource "azurerm_network_security_group" "vpn" {
  name                = "vpn_nsg"
  resource_group_name = azurerm_resource_group.vpn.name
  location            = azurerm_resource_group.vpn.location
}

resource "azurerm_network_security_rule" "allow_internet_ssh" {
  name                        = "allow_internet_ssh"
  resource_group_name         = azurerm_resource_group.vpn.name
  network_security_group_name = azurerm_network_security_group.vpn.name
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = 22
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  access                      = "Allow"
  priority                    = 200
  direction                   = "Inbound"
}

resource "azurerm_subnet_network_security_group_association" "vpn" {
  subnet_id                 = azurerm_subnet.vpn.id
  network_security_group_id = azurerm_network_security_group.vpn.id
}

resource "azurerm_public_ip" "jumpbox" {
  name                = "jumpbox_public_ip"
  resource_group_name = azurerm_resource_group.vpn.name
  location            = azurerm_resource_group.vpn.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "jumpbox" {
  name                = "jumpbox_nic"
  resource_group_name = azurerm_resource_group.vpn.name
  location            = azurerm_resource_group.vpn.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vpn.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(one(azurerm_subnet.vpn.address_prefixes), 4)
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
  }
}

resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                = "jumpbox"
  resource_group_name = azurerm_resource_group.vpn.name
  location            = azurerm_resource_group.vpn.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"

  network_interface_ids = [azurerm_network_interface.jumpbox.id]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file(var.ssh_public_key_file)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/server_startup_script.sh.tftpl", {
    cloud = "Azure"
    region = azurerm_resource_group.vpn.location
  }))
}

