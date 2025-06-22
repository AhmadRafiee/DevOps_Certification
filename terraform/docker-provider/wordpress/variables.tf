variable "network_name" {
  type        = string
  default     = "app_net"
  description = "docker network name"
}

variable "db_image" {
  type        = string
  default     = "mysql:5.7"
  description = "Mysql container image"
}

variable "db_container_name" {
  type        = string
  default     = "db"
  description = "Mysql container name"
}

variable "db_hostname" {
  type        = string
  default     = "mysql"
  description = "Mysql container hostname"
}

variable "db_rootpaas" {
  type        = string
  default     = "sdfweweseweekjklada"
  description = "Mysql root password"
}

variable "db_database" {
  type        = string
  default     = "DockerMe"
  description = "Mysql wordpress database"
}

variable "db_username" {
  type        = string
  default     = "MeCan"
  description = "Mysql username"
}

variable "db_password" {
  type        = string
  default     = "sdfwewesdfsseweekjklada"
  description = "Mysql MeCan user password"
}

variable "db_volume" {
  type        = string
  default     = "db_data"
  description = "Mysql data volumes"
}

variable "db_mount_path" {
  type        = string
  default     = "/var/lib/mysql"
  description = "Mysql data path"
}

variable "wp_image" {
  type        = string
  default     = "wordpress:latest"
  description = "Wordpress image name"
}

variable "wp_container_name" {
  type        = string
  default     = "wordpress"
  description = "Wordpress container name"
}

variable "wp_hostname" {
  type        = string
  default     = "wordpress"
  description = "Wordpress container hostname"
}

variable "wp_volume" {
  type        = string
  default     = "wp_data"
  description = "Wordpress data volumes"
}

variable "wp_mount_path" {
  type        = string
  default     = "/var/www/html"
  description = "Wordpress data path"
}
