terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.36.0"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "5.2.0"
    }
    minio = {
      source = "aminueza/minio"
      version = "3.3.0"
    }
    null = {
      source = "hashicorp/null"
      version = "3.2.4"
    }
  }
}


provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = "damavand"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "damavand"
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "minio" {
  minio_server   = var.minio_api_domain
  minio_region   = "us-east-1"
  minio_user     = var.minio_root_username
  minio_password = var.minio_root_password
  minio_ssl      = true
}
