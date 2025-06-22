variable "image_name" {
  description = "The name for the image to be uploaded"
  type        = string
  default     = "my-cirros"  # Change to your desired image name
}

variable "image_url" {
  description = "Path to the image file to be uploaded"
  type        = string
  default     = "http://download.cirros-cloud.net/0.6.3/cirros-0.6.3-aarch64-disk.img"  # Replace with your actual file path
}

variable "image_disk_format" {
  description = "Disk format of the image (qcow2, raw, etc.)"
  type        = string
  default     = "raw"  # Change based on your image format
}

variable "image_container_format" {
  description = "Container format of the image (bare, ovf, etc.)"
  type        = string
  default     = "bare"  # Specify the container format
}