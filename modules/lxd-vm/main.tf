# ---------------------------------------------------------------------------
# LXD Virtual Machine Module
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    lxd = {
      source  = "terraform-lxd/lxd"
      version = "~> 2.0"
    }
  }

}

# ---------------------------------------------------------------------------
# Cloud-init template - ssh key for ansible user (defined in cloud-init/user-data.yaml) and vm hostname
# ---------------------------------------------------------------------------
locals {
  # 1. Build the full name first
  instance_name = "${var.environment}-${var.os_type}-${var.vm_name}"

  # 2. Pass the full name into your cloud-init
  user_data = templatefile("${path.module}/cloud-init/user-data.yaml", {
    ansible_ssh_public_key = var.ansible_ssh_public_key
    vm_hostname            = local.instance_name # Changed from var.vm_name
  })
}

# ---------------------------------------------------------------------------
# Ubuntu 24.04 Virtual Machine
# ---------------------------------------------------------------------------
resource "lxd_instance" "ubuntu_vm" {
  name    = local.instance_name
  image   = var.image
  type    = "virtual-machine"
  running = true

  # cloud-init user-data
  config = {
    "user.user-data" = local.user_data
    # Ensure cloud-init runs on first boot
    "boot.autostart" = "true"
  }

  # NIC – attach to lxdbr0 (DHCP is handled by cloud-init / netplan)
  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = var.network
    }
  }

  # Root disk
  device {
    name = "root"
    type = "disk"
    properties = {
      pool = var.storage_pool
      path = "/"
      size = var.disk_size
    }
  }

  # CPU & memory limits
  limits = {
    cpu    = tostring(var.cpu_count)
    memory = var.memory_size
  }
}
