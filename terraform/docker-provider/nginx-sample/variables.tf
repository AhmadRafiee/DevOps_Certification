variable "container_image" {
  type        = string
  default     = "nginx:alpine"
  description = "Docker image for container"
}
variable "container_name" {
  type        = string
  default     = "nginx-mecan"
  description = "Container Name"
}
variable "container_hostname" {
  type        = string
  default     = "MeCan"
  description = "Container hostname"
}