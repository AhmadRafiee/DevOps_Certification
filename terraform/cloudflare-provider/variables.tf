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

variable "a_record_name" {
  description = "The name for the A record"
  type        = string
  default     = "app"
}

variable "a_record_value" {
  description = "The IP address for the A record"
  type        = string
  default     = "192.168.200.1"
}

variable "cname_record_name" {
  description = "The name for the CNAME record"
  type        = string
  default     = "www"
}

variable "cname_record_value" {
  description = "The value for the CNAME record"
  type        = string
  default     = "dockerme.ir"
}

variable "txt_record_name" {
  description = "The name for the TXT record"
  type        = string
  default     = "verification"
}

variable "txt_record_value" {
  description = "The data for the TXT record"
  type        = string
  default     = "this is test"
}