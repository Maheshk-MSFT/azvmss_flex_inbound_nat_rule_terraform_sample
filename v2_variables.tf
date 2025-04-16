
variable "admin_username" {
  description = "User name to use as the admin account on the VMs that will be part of the VM scale set"
  default     = "azureuser"
}

variable "admin_password" {
  description = "Default password for admin account"
  default     = ""
  sensitive   = true
}

variable "sku" {
  description = "VMSS sku"
  default     = "Standard_D4s_v3"
}

variable "backend_port" {
  description = "backend_port"
  default     = "80"
}

variable "frontend_port" {
  description = "frontend_port"
  default     = "8080"
}

variable "location" {
  description = "location"
  default     = "centralindia"
}

