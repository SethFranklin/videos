
provider "aws" {
  region = local.AWS_REGION
}

resource "aws_vpc" "vpn" {
  cidr_block = local.AWS_ADDRESS_SPACE

  tags = {
    Name = "vpn_vpc"
  }
}

resource "aws_internet_gateway" "vpn" {
  vpc_id = aws_vpc.vpn.id

  tags = {
    Name = "vpn_internet_gateway"
  }
}

resource "aws_vpn_gateway" "vpn" {
  vpc_id = aws_vpc.vpn.id

  tags = {
    Name = "vpn_vpn_gateway"
  }
}

resource "aws_customer_gateway" "vpn" {
  bgp_asn    = 65000
  ip_address = data.azurerm_public_ip.vpn.ip_address
  type       = "ipsec.1"

  tags = {
    Name = "vpn_customer_gateway"
  }
}

resource "aws_vpn_connection" "vpn" {
  vpn_gateway_id      = aws_vpn_gateway.vpn.id
  customer_gateway_id = aws_customer_gateway.vpn.id
  type                = "ipsec.1"
  static_routes_only  = true

  tunnel1_preshared_key = random_string.tunnel1_preshared_key.result
  tunnel2_preshared_key = random_string.tunnel2_preshared_key.result

  tags = {
    Name = "vpn_vpn_connection"
  }
}

resource "aws_vpn_connection_route" "azure_bound_route" {
  destination_cidr_block = local.AZURE_ADDRESS_SPACE
  vpn_connection_id      = aws_vpn_connection.vpn.id
}

resource "aws_subnet" "vpn" {
  vpc_id            = aws_vpc.vpn.id
  cidr_block        = local.AWS_ADDRESS_SPACE
  availability_zone = "${local.AWS_REGION}a"

  tags = {
    Name = "vpn_subnet"
  }
}

resource "aws_route_table" "vpn" {
  vpc_id = aws_vpc.vpn.id

  tags = {
    Name = "vpn_route_table"
  }
}

resource "aws_main_route_table_association" "vpn" {
  vpc_id         = aws_vpc.vpn.id
  route_table_id = aws_route_table.vpn.id
}

resource "aws_route" "internet_bound_route" {
  route_table_id         = aws_route_table.vpn.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.vpn.id
}

resource "aws_route" "azure_bound_route" {
  route_table_id         = aws_route_table.vpn.id
  destination_cidr_block = local.AZURE_ADDRESS_SPACE
  gateway_id             = aws_vpn_gateway.vpn.id
}

resource "aws_security_group" "jumpbox" {
  name        = "jumpbox_sg"
  description = "AWS Jumpbox Security Group"
  vpc_id      = aws_vpc.vpn.id

  tags = {
    Name = "jumpbox_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_internet_ssh" {
  security_group_id = aws_security_group.jumpbox.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_azure_http" {
  security_group_id = aws_security_group.jumpbox.id

  cidr_ipv4   = local.AZURE_ADDRESS_SPACE
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_azure_ping" {
  security_group_id = aws_security_group.jumpbox.id

  cidr_ipv4   = local.AZURE_ADDRESS_SPACE
  ip_protocol = "icmp"
  from_port   = -1
  to_port     = -1
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.jumpbox.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1
}

resource "aws_network_interface" "jumpbox" {
  subnet_id       = aws_subnet.vpn.id
  private_ips     = [cidrhost(aws_subnet.vpn.cidr_block, 4)]
  security_groups = [aws_security_group.jumpbox.id]
}

resource "aws_eip" "jumpbox" {
  domain   = "vpc"
  instance = aws_instance.jumpbox.id
}

data "aws_ami" "jumpbox" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "jumpbox" {
  key_name   = "jumpbox_key"
  public_key = file(var.ssh_public_key_file)
}

resource "aws_instance" "jumpbox" {
  ami           = data.aws_ami.jumpbox.id
  instance_type = "t2.micro"

  key_name = aws_key_pair.jumpbox.key_name

  network_interface {
    network_interface_id = aws_network_interface.jumpbox.id
    device_index         = 0
  }

  user_data_base64 = base64encode(templatefile("${path.module}/server_startup_script.sh.tftpl", {
    cloud  = "AWS"
    region = local.AWS_REGION
  }))
}
