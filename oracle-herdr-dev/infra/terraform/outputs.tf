output "public_ip" {
  value = oci_core_instance.dev.public_ip
}

output "image" {
  value = data.oci_core_images.ol9.images[0].display_name
}

output "ssh_command" {
  description = "Workspace 1 ports forwarded; see docs/installation.md for the others."
  value       = "ssh -L 5173:localhost:5173 -L 8081:localhost:8081 -L 8181:localhost:8181 -L 5433:localhost:5433 opc@${oci_core_instance.dev.public_ip}"
}
