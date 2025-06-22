variable "bucket_name" {
  description = "The name of the bucket to create"
  type        = string
  default     = "etcd-backup"
}

variable "user_name" {
  description = "The name of the user to create"
  type        = string
  default     = "etcd-backup-user"
}

variable "user_password" {
  description = "The password for the user"
  type        = string
  default     = "BbsdcsdeswevwecHGd7V"
}

variable "policy_name" {
  description = "The name of the policy to create"
  type        = string
  default     = "etcd-backup-policy"
}