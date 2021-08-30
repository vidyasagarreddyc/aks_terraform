variable infra {}
variable tags {}
variable "admin_password" {
    default = null
}
variable "client_id" {
  default = null
}
variable "client_secret" {
  default = null
}

variable "public_ssh_key" {
  description = "A custom ssh key to control access to the AKS cluster"
  type        = string
  default     = ""
}