variable "image_id" {
  description = "The image id"
  type        = string
  default     = "269fdce3-da68-4c6a-b5b4-f0535d744910"
}

variable "flavor_id" {
  description = "the flavor id"
  type        = string
  default     = "ef06d321-3711-4f80-9fc3-2f74e91208d6	"
}

variable "key_pair_name" {
  description = "the key_pair name"
  type        = string
  default     = "my-keypair"
}

variable "network_name" {
  description = "the network name"
  type        = string
  default     = "internal-network"
}