
source "azure-arm" "windows" {
  os_type         = "Windows"
  image_offer     = "WindowsServer"
  image_publisher = "MicrosoftWindowsServer"
  image_sku       = "2025-datacenter-g2"

  vm_size = "Standard_D2s_v3"

  virtual_network_resource_group_name = "packer"
  virtual_network_name                = "packer_vnet"
  virtual_network_subnet_name         = "build_subnet"

  build_resource_group_name = "packer"
  temp_compute_name         = "windowsbuild"
  temp_nic_name             = "windowsbuild"
  temp_os_disk_name         = "windowsbuild"

  managed_image_resource_group_name = "packer"
  managed_image_name                = "windowsiis"

  communicator = "winrm"

  winrm_insecure = true
  winrm_timeout  = "5m"
  winrm_use_ssl  = true
  winrm_username = "packer"
}

build {
  sources = ["source.azure-arm.windows"]

  provisioner "powershell" {
    script = "${path.root}/windows_iis_script.ps1"
  }
}

