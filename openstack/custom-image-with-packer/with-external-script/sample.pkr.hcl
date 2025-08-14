packer {
  required_plugins {
    openstack = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/openstack"
    }
  }
}
variable "identity_endpoint" {
  type    = string
  default = env("OS_AUTH_URL")
}

variable "username" {
  type    = string
  default = env("OS_USERNAME")
}

variable "password" {
  type    = string
  default = env("OS_PASSWORD")
}

variable "tenant_name" {
  type    = string
  default = env("OS_PROJECT_NAME")
}

variable "domain_name" {
  type    = string
  default = env("OS_USER_DOMAIN_NAME")
}

variable "region" {
  type    = string
  default = env("OS_REGION_NAME")
}

variable "image_id" {
  type    = string
  default = env("SOURCE_ID")
}

variable "flavor_id" {
  type    = string
  default = env("FLAVOR_ID")
}

variable "network_id" {
  type    = string
  default = env("NETWORK_ID")
}

variable "scurity_group_name" {
  type    = string
  default = env("SECURITY_GROUP_NAME")
}

variable "volume_type_name" {
  type    = string
  default = env("VOLUME_TYPE_NAME")
}

variable "volume_availability_zone_name" {
  type    = string
  default = env("VOLUME_AVAILABILITY_ZONE_NAME")
}

source "openstack" "custom_image" {
  identity_endpoint = var.identity_endpoint
  username          = var.username
  password          = var.password
  tenant_name       = var.tenant_name
  domain_name       = var.domain_name
  region            = var.region

  image_name        = "debian_with_docker"
  image_visibility  = "Public"
  image_disk_format = "qcow2"

  source_image      = "8edf0384-2feb-41c5-8398-40bc4ff985e1"
  flavor            = "93af1a59-ea02-49fc-a97b-fa401bff4954"
  networks          = ["2c55bc89-e729-451f-a9cc-48e26baf4085"]
  security_groups   = ["default"]

  use_blockstorage_volume = true
  volume_type       = "__DEFAULT__"
  volume_size       = 5
  availability_zone = "nova"

  ssh_username      = "debian"
  ssh_ip_version    = 4
}

build {
  sources = ["source.openstack.custom_image"]

  provisioner "shell" {
    script = "provisioner.sh"
  }
}

