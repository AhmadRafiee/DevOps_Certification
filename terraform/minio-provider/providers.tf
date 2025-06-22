terraform {
  required_providers {
    minio = {
      source = "aminueza/minio"
      version = "3.3.0"
    }
  }
}

provider "minio" {
  minio_server   = "MINIO_API_DOMAIN"
  minio_region   = "us-east-1"
  minio_user     = "MINIO_ACCESS_KEY"
  minio_password = "MINIO_SECRET_KEY"
  minio_ssl      = true
}