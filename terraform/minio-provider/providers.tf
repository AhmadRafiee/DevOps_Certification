terraform {
  required_providers {
    minio = {
      source = "aminueza/minio"
      version = "3.3.0"
    }
  }
}

provider "minio" {
  minio_server   = "API_URL_DOMAIN"
  minio_region   = "us-east-1"
  minio_user     = "ACCESS_KEY"
  minio_password = "SECRET_KEY"
  minio_ssl      = true
}