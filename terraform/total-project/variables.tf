# variables.tf
variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  default     = "CLOUDFLARE_API_TOKEN"
}

variable "zone_id" {
  description = "The DNS zone id"
  type        = string
  default     = "CLOUDFLARE_ZONE_ID"
}

variable "minio_api_domain" {
  description = "The name for the CNAME record"
  type        = string
  default     = "obj.kube.mecan.ir"
}

variable "cname_value_api" {
  description = "The value for the CNAME record"
  type        = string
  default     = "vip.kube.mecan.ir"
}

variable "minio_console_domain" {
  description = "The name for the CNAME record"
  type        = string
  default     = "io.kube.mecan.ir"
}

variable "cname_value_panel" {
  description = "The value for the CNAME record"
  type        = string
  default     = "vip.kube.mecan.ir"
}

variable "bucket_name" {
  description = "The name of the bucket to create"
  type        = string
  default     = "velero-backup"
}

variable "minio_velero_username" {
  description = "The name of the user to create"
  type        = string
  default     = "MINIO_VELERO_USERNAME"
}

variable "minio_velero_password" {
  description = "The password for the user"
  type        = string
  default     = "MINIO_VELERO_PASSWORD"
}

variable "policy_name" {
  description = "The name of the policy to create"
  type        = string
  default     = "velero-backup-policy"
}

variable "minio_root_username" {
  description = "The minio access key"
  type        = string
  default     = "MINIO_ROOT_USERNAME"
}

variable "minio_root_password" {
  description = "The minio secret key"
  type        = string
  default     = "MINIO_ROOT_PASSWORD"
}
