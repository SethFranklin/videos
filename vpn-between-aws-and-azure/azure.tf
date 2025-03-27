
provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}

locals {
  azure_subnet_cidrs = cidrsubnets(local.AZURE_ADDRESS_SPACE, 1, 1)
}

resource "azurerm_resource_group" "vpn" {
  name     = "vpn"
  location = local.AZURE_REGION
}

resource "azurerm_virtual_network" "vpn" {
  name                = "vpn_vnet"
  resource_group_name = azurerm_resource_group.vpn.name
  location            = azurerm_resource_group.vpn.location
  address_space       = [local.AZURE_ADDRESS_SPACE]
}

resource "azurerm_subnet" "jumpbox" {
  name                 = "vpn_jumpbox"
  resource_group_name  = azurerm_resource_group.vpn.name
  virtual_network_name = azurerm_virtual_network.vpn.name
  address_prefixes     = [local.azure_subnet_cidrs[0]]
}

resource "azurerm_subnet" "vpn" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.vpn.name
  virtual_network_name = azurerm_virtual_network.vpn.name
  address_prefixes     = [local.azure_subnet_cidrs[1]]
}

resource "azurerm_public_ip" "vpn" {
  name                = "vpn_gateway_public_ip"
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

data "azurerm_public_ip" "vpn" {
  name                = azurerm_public_ip.vpn.name
  resource_group_name = azurerm_resource_group.vpn.name
  depends_on          = [azurerm_virtual_network_gateway.vpn]
}

resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "vpn_gateway"
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "Basic"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vpn.id
  }

  vpn_client_configuration {
    address_space = [local.AWS_ADDRESS_SPACE]
  }
}

resource "azurerm_local_network_gateway" "vpn_tunnel1" {
  name                = "vpn_local_network_gateway_tunnel1"
  resource_group_name = azurerm_resource_group.vpn.name
  location            = azurerm_resource_group.vpn.location
  gateway_address     = aws_vpn_connection.vpn.tunnel1_address
  address_space       = [local.AWS_ADDRESS_SPACE]
}

resource "azurerm_virtual_network_gateway_connection" "vpn_tunnel1" {
  name                = "local_network_gateway_connection_tunnel1"
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.vpn_tunnel1.id

  shared_key = random_string.tunnel1_preshared_key.result
}

resource "azurerm_local_network_gateway" "vpn_tunnel2" {
  name                = "vpn_local_network_gateway_tunnel2"
  resource_group_name = azurerm_resource_group.vpn.name
  location            = azurerm_resource_group.vpn.location
  gateway_address     = aws_vpn_connection.vpn.tunnel2_address
  address_space       = [local.AWS_ADDRESS_SPACE]
}

resource "azurerm_virtual_network_gateway_connection" "vpn_tunnel2" {
  name                = "local_network_gateway_connection_tunnel2"
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.vpn_tunnel2.id

  shared_key = random_string.tunnel2_preshared_key.result
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

resource "azurerm_network_security_rule" "allow_aws_http" {
  name                        = "allow_aws_http"
  resource_group_name         = azurerm_resource_group.vpn.name
  network_security_group_name = azurerm_network_security_group.vpn.name
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = 80
  source_address_prefix       = local.AWS_ADDRESS_SPACE
  destination_address_prefix  = "*"
  access                      = "Allow"
  priority                    = 300
  direction                   = "Inbound"
}

resource "azurerm_network_security_rule" "allow_aws_ping" {
  name                        = "allow_aws_ping"
  resource_group_name         = azurerm_resource_group.vpn.name
  network_security_group_name = azurerm_network_security_group.vpn.name
  protocol                    = "Icmp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = local.AWS_ADDRESS_SPACE
  destination_address_prefix  = "*"
  access                      = "Allow"
  priority                    = 400
  direction                   = "Inbound"
}

resource "azurerm_subnet_network_security_group_association" "vpn" {
  subnet_id                 = azurerm_subnet.jumpbox.id
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
    subnet_id                     = azurerm_subnet.jumpbox.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(one(azurerm_subnet.jumpbox.address_prefixes), 4)
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
  }
}

resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                = "jumpbox"
  resource_group_name = azurerm_resource_group.vpn.name
  location            = azurerm_resource_group.vpn.location
  size                = "Standard_B1s"
  admin_username      = "ubuntu"

  network_interface_ids = [azurerm_network_interface.jumpbox.id]

  admin_ssh_key {
    username   = "ubuntu"
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
    cloud  = "Azure"
    region = azurerm_resource_group.vpn.location
  }))
}

