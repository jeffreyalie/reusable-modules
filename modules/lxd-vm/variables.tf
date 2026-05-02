# ---------------------------------------------------------------------------
# LXD Configuration
# ---------------------------------------------------------------------------
variable "lxd_address" {
  description = "LXD server address (set via CI secret: LXD_ADDRESS)"
  type        = string
}

# variable "lxd_trust_password" {
#   type        = string
#   description = "The trust password for the LXD host"
#   sensitive   = true
# }

# ---------------------------------------------------------------------------
# VM Configuration (defined in tfvars)
# ---------------------------------------------------------------------------
variable "vm_name" {
  description = "Input from GHA TF_VAR_vm_name (e.g. dev01) and Combined in locals to form vm name"
  type        = string
}

variable "os_type" {
  type    = string
  description = "Combined in locals to form vm name"
}

variable "environment" {
  type        = string
  description = "Passed from GHA input TFVAR_environment (e.g. dev, staging, prod) amd Combined in locals to form vm name"
}

variable "image" {
  type    = string
  default = ""
}

variable "network" {
  type    = string
  default = ""
}

variable "storage_pool" {
  description = "LXD storage pool name (defined in tfvars)"
  type        = string
}

variable "disk_size" {
  description = "Disk size (e.g. 20GB) (defined in tfvars)"
  type        = string
}

variable "cpu_count" {
  description = "Number of CPUs (defined in tfvars)"
  type        = number
}

variable "memory_size" {
  description = "Memory size (e.g. 2GB) (defined in tfvars)"
  type        = string
}

# ---------------------------------------------------------------------------
# SSH Configuration (Ansible) used for cloud init to setup the VM for Ansible access
# ---------------------------------------------------------------------------
variable "ansible_ssh_public_key" {
  description = "SSH public key injected into VM (set via CI secret: ANSIBLE_SSH_PUBLIC_KEY)"
  type        = string
}
