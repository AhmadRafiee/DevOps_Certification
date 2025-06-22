variable "namespace_name" {
  description = "The name of the Kubernetes namespace"
  type        = string
  default     = "web"
}

variable "deployment_name" {
  description = "The name of the deployment"
  type        = string
  default     = "web"
}

variable "replicas" {
  description = "Number of replicas"
  type        = number
  default     = 3
}

variable "image" {
  description = "Docker image to use for the deployment"
  type        = string
  default     = "nginx:latest"
}