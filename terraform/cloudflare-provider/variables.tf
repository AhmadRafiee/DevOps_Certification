# variables.tf
variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  default     = "Cloudflare_API_Token"  # Change this to your desired subdomain
}

variable "zone_id" {
  description = "The DNS zone id"
  type        = string
  default     = "ZONE_ID"
}

variable "a_record_name" {
  description = "The name for the A record"
  type        = string
  default     = "app"  # Change this to your desired subdomain
}

variable "a_record_value" {
  description = "The IP address for the A record"
  type        = string
  default     = "192.168.200.1"
}

variable "cname_record_name" {
  description = "The name for the CNAME record"
  type        = string
  default     = "www"  # Change this to your desired subdomain
}

variable "cname_record_value" {
  description = "The value for the CNAME record"
  type        = string
  default     = "dockerme.ir"  # Change this to your desired subdomain
}

variable "txt_record_name" {
  description = "The name for the TXT record"
  type        = string
  default     = "verification"  # Change this to your desired subdomain
}

variable "txt_record_value" {
  description = "The data for the TXT record"
  type        = string
  default     = "this is test"  # Change this to your actual value
}