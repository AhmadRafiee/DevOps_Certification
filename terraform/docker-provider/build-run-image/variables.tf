variable "image_name" {
  description = "The name of the Docker image"
  type        = string
  default     = "mecan_nginx_app"
}

variable "container_name" {
  description = "The name of the Docker container"
  type        = string
  default     = "mecan_container"
}

