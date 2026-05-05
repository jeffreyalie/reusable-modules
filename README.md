# Reusable Modules

Shared Terraform modules for the `Infra` org. This repo hosts the `lxd-vm` module — the canonical definition of how a VM is provisioned on LXD. All repos in the org reference this module by default; a local copy is only used when customisation is needed.

---

## Table of Contents

- [Overview](#overview)
- [Modules](#modules)
- [lxd-vm Module](#lxd-vm-module)
- [How to Reference This Module](#how-to-reference-this-module)
- [Local Module Fallback](#local-module-fallback)
- [Input Reference](#input-reference)
- [Outputs Reference](#outputs-reference)
- [cloud-init Template](#cloud-init-template)
- [VM Naming Convention](#vm-naming-convention)
- [Design Notes](#design-notes)

---

## Overview

```
reusable-modules/
└── modules/
    └── lxd-vm/
        ├── main.tf                  # lxd_instance resource + locals
        ├── variables.tf             # all module input variables
        ├── outputs.tf               # vm_name, vm_ip, vm_mac_address, ansible_ssh_command
        └── cloud-init/
            └── user-data.yaml       # cloud-init template (ansible user, SSH hardening)
```

Versioning is via git ref — use `@main` for the latest or pin to a tag (e.g. `@v1.0.0`) for stability across environments.

---

## Modules

| Module | Path | Description |
|---|---|---|
| `lxd-vm` | `modules/lxd-vm` | Provisions an Ubuntu 24.04 VM on LXD with cloud-init |

---

## lxd-vm Module

Encapsulates a single LXD virtual machine with:
- `lxd_instance` resource (type `virtual-machine`)
- cloud-init `user-data.yaml` rendered via `templatefile()`
- NIC attached to `lxdbr0` (DHCP via cloud-init/netplan)
- Root disk on a configurable storage pool
- CPU and memory limits
- Outputs for downstream use (VM IP, SSH command)

### What cloud-init Does

On first boot, cloud-init:
1. Sets hostname to the full instance name (`<environment>-<os_type>-<vm_name>`)
2. Configures DHCP on `enp5s0` via netplan
3. Creates an `ansible` user with SSH key auth and passwordless sudo
4. Installs base packages: `curl`, `wget`, `git`, `python3`, `openssh-server`, `ca-certificates`, `net-tools`
5. Writes SSH hardening config (disables password auth, disables root login)
6. Restarts sshd

---

## How to Reference This Module

In your environment's `main.tf`, source the module via `git::http://`:

```hcl
module "vm" {
  source = "git::http://gitea.local/Infra/reusable-modules.git//modules/lxd-vm?ref=main"

  vm_name                = var.vm_name
  os_type                = var.os_type
  environment            = var.environment
  ansible_ssh_public_key = var.ansible_ssh_public_key
  lxd_address            = var.lxd_address
  image                  = var.image
  network                = var.network
  storage_pool           = var.storage_pool
  disk_size              = var.disk_size
  cpu_count              = var.cpu_count
  memory_size            = var.memory_size
}
```

**Pinning to a specific version:**
```hcl
source = "git::http://gitea.local/Infra/reusable-modules.git//modules/lxd-vm?ref=v1.2.0"
```

After changing `source` or the `ref`, always run `terraform init -upgrade` to pull the updated module.

---

## Local Module Fallback

If you need to customise the module for a specific repo without affecting others, copy the module locally and change `source` to a relative path:

```hcl
module "vm" {
  source = "../../modules/lxd-vm"   # local copy inside your repo

  # same inputs
}
```

The local copy lives at `terraform/modules/lxd-vm/` in the calling repo. Once your changes are stable and ready to be shared, open a PR to this repo to promote them back.

**When to use local vs reusable:**

| Use reusable (`git::http://`) | Use local (`../../modules/`) |
|---|---|
| Standard VM provisioning | Customising cloud-init packages or behaviour |
| Consistent across all repos | Adding new LXD device types (GPUs, extra disks) |
| Prod-grade, version-pinned | Iterating quickly without cross-repo impact |

---

## Input Reference

| Variable | Type | Required | Default | Description |
|---|---|---|---|---|
| `vm_name` | `string` | Yes | — | Short name (e.g. `dev01`). Combined with `environment` and `os_type` to form the full instance name. |
| `os_type` | `string` | Yes | — | OS label (e.g. `ubuntu-vm`). Included in the instance name. |
| `environment` | `string` | Yes | — | Environment label (e.g. `dev`, `prod`). Included in the instance name. |
| `lxd_address` | `string` | Yes | — | LXD API host IP. Set via `TF_VAR_lxd_address` from secrets. |
| `ansible_ssh_public_key` | `string` | Yes | — | SSH public key injected into the VM for the `ansible` user. Set via `TF_VAR_ansible_ssh_public_key`. |
| `image` | `string` | No | `""` | LXD image alias (e.g. `ubuntu-24-04-vm`). |
| `network` | `string` | No | `""` | LXD network bridge (e.g. `lxdbr0`). |
| `storage_pool` | `string` | Yes | — | LXD storage pool name (e.g. `default`). |
| `disk_size` | `string` | Yes | — | Root disk size (e.g. `10GiB`). |
| `cpu_count` | `number` | Yes | — | vCPU count. |
| `memory_size` | `string` | Yes | — | Memory allocation (e.g. `2GiB`). |

**Sensitive inputs (never in tfvars — inject via `TF_VAR_*`):**
- `lxd_address`
- `ansible_ssh_public_key`

---

## Outputs Reference

| Output | Description | Example value |
|---|---|---|
| `vm_name` | Full constructed instance name | `dev-ubuntu-vm-dev01` |
| `vm_ip` | IPv4 address assigned by DHCP | `10.x.x.x` |
| `vm_mac_address` | MAC address of the VM's NIC | `00:16:3e:xx:xx:xx` |
| `ansible_ssh_command` | Ready-to-use SSH command | `ssh ansible@10.x.x.x` |

Consume outputs in a calling environment:

```hcl
# terraform/env/dev/outputs.tf
output "vm_ip" {
  value = module.vm.vm_ip
}

output "ansible_ssh_command" {
  value = module.vm.ansible_ssh_command
}
```

The `ansible-deploy` workflow reads `vm_ip` via `terraform output -raw vm_ip` to build the Ansible inventory.

---

## cloud-init Template

The template at `modules/lxd-vm/cloud-init/user-data.yaml` is rendered by Terraform's `templatefile()` inside `locals`. Two variables are interpolated:

| Template variable | Source |
|---|---|
| `${vm_hostname}` | `local.instance_name` — the full constructed name |
| `${ansible_ssh_public_key}` | `var.ansible_ssh_public_key` — from secrets |

**Network interface note:** The template configures `enp5s0` — the default primary NIC name for Ubuntu 24.04 VMs on LXD. If you use a different image or LXD version that names the interface differently, update the `ethernets:` key in the template.

**Extending cloud-init:** To add extra packages or run additional commands on first boot, edit the `packages:` list or `runcmd:` section. When doing this in the shared module, ensure the additions are universally safe. For repo-specific changes, use the local module fallback instead.

---

## VM Naming Convention

The full instance name is constructed in `locals` inside `main.tf`:

```hcl
locals {
  instance_name = "${var.environment}-${var.os_type}-${var.vm_name}"
}
```

Examples:

| `environment` | `os_type` | `vm_name` | Full name |
|---|---|---|---|
| `dev` | `ubuntu-vm` | `dev01` | `dev-ubuntu-vm-dev01` |
| `prod` | `ubuntu-vm` | `prod02` | `prod-ubuntu-vm-prod02` |

This name is used as both the LXD instance name and the cloud-init hostname. It must be unique within an LXD host.

---

## Design Notes

**Why a shared module instead of copying `main.tf` per environment?**
LXD instance configuration — device layout, cloud-init rendering, naming logic — is identical across environments. Sharing it from one repo means bug fixes and improvements propagate everywhere via a `ref` bump, rather than requiring manual edits across multiple repos.

**Why `git::http://` instead of a Terraform registry?**
The homelab uses Gitea, which doesn't natively serve a Terraform module registry protocol. The `git::http://` source type is Terraform's built-in fallback for any git-hosted module — it works with Gitea without additional infrastructure.

**Why not use `terraform-lxd/lxd` provider version `v1.x`?**
This module targets provider `~> 2.0`. The `lxd_remote` block syntax changed significantly between v1 and v2. Do not downgrade the provider constraint without reviewing the remote configuration in `providers.tf`.

---

## Infrastructure Created and Maintained by

**Ali Ahmed**  
Building infrastructure, automation, and DevOps workflows

**Contact**

[![GitHub](https://img.shields.io/badge/GitHub-%20ali%20ahmed-black?style=for-the-badge&logo=github)](https://github.com/jeffreyalie)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-%20ali%20ahmed-blue?style=for-the-badge&logo=linkedin)](https://www.linkedin.com/in/ali-ahmed-261755252/)
