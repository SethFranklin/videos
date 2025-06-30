
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

locals {
  ADDRESS_SPACE = "10.0.0.0/27"
  REGION        = "eastus"

  subnet_cidrs = cidrsubnets(local.ADDRESS_SPACE, 2, 2, 2)
}


resource "azurerm_resource_group" "packer" {
  name     = "packer"
  location = local.REGION
}

resource "azurerm_virtual_network" "packer" {
  name                = "packer_vnet"
  resource_group_name = azurerm_resource_group.packer.name
  location            = azurerm_resource_group.packer.location
  address_space       = [local.ADDRESS_SPACE]
}

resource "azurerm_subnet" "dmz" {
  name                 = "dmz_subnet"
  resource_group_name  = azurerm_resource_group.packer.name
  virtual_network_name = azurerm_virtual_network.packer.name
  address_prefixes     = [local.subnet_cidrs[0]]
}

resource "azurerm_subnet" "build" {
  name                 = "build_subnet"
  resource_group_name  = azurerm_resource_group.packer.name
  virtual_network_name = azurerm_virtual_network.packer.name
  address_prefixes     = [local.subnet_cidrs[1]]
}

resource "azurerm_subnet" "test_deploy" {
  name                 = "test_deploy_subnet"
  resource_group_name  = azurerm_resource_group.packer.name
  virtual_network_name = azurerm_virtual_network.packer.name
  address_prefixes     = [local.subnet_cidrs[2]]
}

resource "azurerm_network_security_group" "dmz" {
  name                = "dmz_nsg"
  resource_group_name = azurerm_resource_group.packer.name
  location            = azurerm_resource_group.packer.location
}

resource "azurerm_network_security_group" "build" {
  name                = "build_nsg"
  resource_group_name = azurerm_resource_group.packer.name
  location            = azurerm_resource_group.packer.location
}

resource "azurerm_network_security_group" "test_deploy" {
  name                = "test_deploy_nsg"
  resource_group_name = azurerm_resource_group.packer.name
  location            = azurerm_resource_group.packer.location
}

resource "azurerm_subnet_network_security_group_association" "dmz" {
  subnet_id                 = azurerm_subnet.dmz.id
  network_security_group_id = azurerm_network_security_group.dmz.id
}

resource "azurerm_subnet_network_security_group_association" "build" {
  subnet_id                 = azurerm_subnet.build.id
  network_security_group_id = azurerm_network_security_group.build.id
}

resource "azurerm_subnet_network_security_group_association" "test_deploy" {
  subnet_id                 = azurerm_subnet.test_deploy.id
  network_security_group_id = azurerm_network_security_group.test_deploy.id
}

resource "azurerm_network_security_rule" "dmz_block_all_inbound" {
  name                        = "dmz_block_all_inbound"
  resource_group_name         = azurerm_resource_group.packer.name
  network_security_group_name = azurerm_network_security_group.dmz.name
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  access                      = "Deny"
  priority                    = 300
  direction                   = "Inbound"
}

resource "azurerm_network_security_rule" "dmz_allow_internet_ssh" {
  name                        = "dmz_allow_internet_ssh"
  resource_group_name         = azurerm_resource_group.packer.name
  network_security_group_name = azurerm_network_security_group.dmz.name
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = 22
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  access                      = "Allow"
  priority                    = 200
  direction                   = "Inbound"
}

resource "azurerm_network_security_rule" "build_block_all_inbound" {
  name                        = "build_block_all_inbound"
  resource_group_name         = azurerm_resource_group.packer.name
  network_security_group_name = azurerm_network_security_group.build.name
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  access                      = "Deny"
  priority                    = 300
  direction                   = "Inbound"
}

resource "azurerm_network_security_rule" "build_allow_dmz_ssh" {
  name                        = "build_allow_dmz_ssh"
  resource_group_name         = azurerm_resource_group.packer.name
  network_security_group_name = azurerm_network_security_group.build.name
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = 22
  source_address_prefix       = azurerm_subnet.dmz.address_prefixes[0]
  destination_address_prefix  = "*"
  access                      = "Allow"
  priority                    = 200
  direction                   = "Inbound"
}

resource "azurerm_network_security_rule" "build_allow_dmz_winrm" {
  name                        = "build_allow_dmz_winrm"
  resource_group_name         = azurerm_resource_group.packer.name
  network_security_group_name = azurerm_network_security_group.build.name
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = 5986
  source_address_prefix       = azurerm_subnet.dmz.address_prefixes[0]
  destination_address_prefix  = "*"
  access                      = "Allow"
  priority                    = 210
  direction                   = "Inbound"
}

resource "azurerm_network_security_rule" "test_deploy_block_all_inbound" {
  name                        = "test_deploy_block_all_inbound"
  resource_group_name         = azurerm_resource_group.packer.name
  network_security_group_name = azurerm_network_security_group.test_deploy.name
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  access                      = "Deny"
  priority                    = 300
  direction                   = "Inbound"
}

resource "azurerm_network_security_rule" "test_deploy_allow_dmz_http" {
  name                        = "test_deploy_allow_dmz_http"
  resource_group_name         = azurerm_resource_group.packer.name
  network_security_group_name = azurerm_network_security_group.test_deploy.name
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = 80
  source_address_prefix       = azurerm_subnet.dmz.address_prefixes[0]
  destination_address_prefix  = "*"
  access                      = "Allow"
  priority                    = 200
  direction                   = "Inbound"
}

resource "azurerm_public_ip" "jumpbox" {
  name                = "jumpbox_public_ip"
  resource_group_name = azurerm_resource_group.packer.name
  location            = azurerm_resource_group.packer.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "jumpbox" {
  name                = "jumpbox_nic"
  resource_group_name = azurerm_resource_group.packer.name
  location            = azurerm_resource_group.packer.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dmz.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.dmz.address_prefixes[0], 4)
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
  }
}

resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                = "jumpbox"
  resource_group_name = azurerm_resource_group.packer.name
  location            = azurerm_resource_group.packer.location
  size                = "Standard_B1s"
  admin_username      = "rhel"

  network_interface_ids = [azurerm_network_interface.jumpbox.id]

  admin_ssh_key {
    username   = "rhel"
    public_key = file(var.ssh_public_key_file)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "96-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(file("${path.module}/packer_startup_script.sh"))
}

resource "azurerm_role_assignment" "jumpbox" {
  scope                = azurerm_resource_group.packer.id
  role_definition_name = "Contributor"
  principal_id         = one(azurerm_linux_virtual_machine.jumpbox.identity).principal_id
}

