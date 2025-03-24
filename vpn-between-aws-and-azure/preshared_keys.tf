
provider "random" {
}

resource "random_string" "tunnel1_preshared_key" {
  length  = 64
  special = false
  numeric = false
}

resource "random_string" "tunnel2_preshared_key" {
  length  = 64
  special = false
  numeric = false
}

