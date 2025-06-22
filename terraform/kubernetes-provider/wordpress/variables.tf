# variables.tf
variable "namespace" {
  description = "Namespace for WordPress deployment"
  type        = string
  default     = "wordpress"
}

variable "mysql_root_password" {
  description = "Root password for MySQL"
  type        = string
  default     = "password"  # Change to a secure password
}

variable "mysql_database" {
  description = "Database name for WordPress"
  type        = string
  default     = "wordpress"
}

variable "wordpress_username" {
  description = "Username for WordPress admin"
  type        = string
  default     = "admin"
}

variable "wordpress_password" {
  description = "Password for WordPress admin"
  type        = string
  default     = "wordpress"  # Change to a secure password
}

variable "host_path" {
  description = "Path on the host to use for storage"
  type        = string
  default     = "/data"  # Adjust according to your host filesystem
}

variable "ingress_host" {
  description = "The host for the Ingress"
  type        = string
  default     = "wordpress.dena.mecan.ir"  # Change to your desired domain
}
