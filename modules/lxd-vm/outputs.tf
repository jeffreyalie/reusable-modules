output "vm_name" {
  description = "Name of the deployed VM"
  value       = lxd_instance.ubuntu_vm.name
}

output "vm_ip" {
  description = "IP address of the VM"
  value       = lxd_instance.ubuntu_vm.ipv4_address
}

output "vm_mac_address" {
  description = "MAC address of the VM's network interface"
  value       = lxd_instance.ubuntu_vm.mac_address
}

output "ansible_ssh_command" {
  description = "SSH command to connect to the VM as the ansible user"
  value       = "ssh ansible@${lxd_instance.ubuntu_vm.ipv4_address}"
}
