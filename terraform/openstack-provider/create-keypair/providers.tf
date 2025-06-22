terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}


provider "openstack" {
  auth_url    = "KEYSTONE_URL"
  tenant_name = "admin"                                       # Project name
  user_name   = "admin"                                       # OpenStack username
  password    = "PASSWORD"                                    # OpenStack password
  region      = "RegionOne"                                   # Region where your OpenStack instance is located
  insecure    = "true"
}