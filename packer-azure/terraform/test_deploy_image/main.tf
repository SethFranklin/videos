
terraform {
  required_version = ">= 1.12.2"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.24.0"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}

data "azurerm_resource_group" "packer" {
  name = "packer"
}

data "azurerm_virtual_network" "packer" {
  name                = "packer_vnet"
  resource_group_name = data.azurerm_resource_group.packer.name
}

data "azurerm_subnet" "test_deploy" {
  name                 = "test_deploy_subnet"
  virtual_network_name = data.azurerm_virtual_network.packer.name
  resource_group_name  = data.azurerm_resource_group.packer.name
}

data "azurerm_image" "rhelapache" {
  name                = "rhelapache"
  resource_group_name = data.azurerm_resource_group.packer.name
}

resource "azurerm_network_interface" "rhelapache" {
  name                = "rhelapache_nic"
  resource_group_name = data.azurerm_resource_group.packer.name
  location            = data.azurerm_resource_group.packer.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.test_deploy.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(data.azurerm_subnet.test_deploy.address_prefixes[0], 4)
  }
}

resource "azurerm_linux_virtual_machine" "rhelapache" {
  name                = "rhelapache"
  resource_group_name = data.azurerm_resource_group.packer.name
  location            = data.azurerm_resource_group.packer.location
  size                = "Standard_B1s"
  admin_username      = "rhel"

  network_interface_ids = [azurerm_network_interface.rhelapache.id]

  admin_ssh_key {
    username   = "rhel"
    public_key = file(var.ssh_public_key_file)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = data.azurerm_image.rhelapache.id
}

data "azurerm_image" "windowsiis" {
  name                = "windowsiis"
  resource_group_name = data.azurerm_resource_group.packer.name
}

resource "azurerm_network_interface" "windowsiis" {
  name                = "windowsiis_nic"
  resource_group_name = data.azurerm_resource_group.packer.name
  location            = data.azurerm_resource_group.packer.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.test_deploy.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(data.azurerm_subnet.test_deploy.address_prefixes[0], 5)
  }
}

resource "azurerm_windows_virtual_machine" "windowsiis" {
  name                = "windowsiis"
  resource_group_name = data.azurerm_resource_group.packer.name
  location            = data.azurerm_resource_group.packer.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"

  network_interface_ids = [azurerm_network_interface.windowsiis.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = data.azurerm_image.windowsiis.id
}

