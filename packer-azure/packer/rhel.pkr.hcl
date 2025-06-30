
source "azure-arm" "rhel" {
  os_type         = "Linux"
  image_offer     = "RHEL"
  image_publisher = "RedHat"
  image_sku       = "96-gen2"

  vm_size = "Standard_B1s"

  virtual_network_resource_group_name = "packer"
  virtual_network_name                = "packer_vnet"
  virtual_network_subnet_name         = "build_subnet"

  build_resource_group_name = "packer"
  temp_compute_name         = "rhelbuild"
  temp_nic_name             = "rhelbuild"
  temp_os_disk_name         = "rhelbuild"

  managed_image_resource_group_name = "packer"
  managed_image_name                = "rhelapache"
}

build {
  sources = ["source.azure-arm.rhel"]

  provisioner "shell" {
    script = "${path.root}/rhel_apache_script.sh"
  }
}

