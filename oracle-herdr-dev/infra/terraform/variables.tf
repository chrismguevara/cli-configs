# --- authentication (leave empty to use ~/.oci/config + config_file_profile) ---
variable "tenancy_ocid" {
  type    = string
  default = null
}
variable "user_ocid" {
  type    = string
  default = null
}
variable "fingerprint" {
  type    = string
  default = null
}
variable "private_key_path" {
  type    = string
  default = null
}
variable "config_file_profile" {
  type    = string
  default = "DEFAULT"
}
variable "region" {
  type        = string
  description = "Home region of the tenancy, e.g. us-phoenix-1 (Always Free resources must be in the home region)."
}

# --- placement ---
variable "compartment_ocid" {
  type        = string
  description = "Compartment to create everything in (the tenancy OCID is the root compartment)."
}
variable "availability_domain_index" {
  type        = number
  default     = 0
  description = "Index into the tenancy's availability domains. Change it on 'Out of host capacity'."
}

# --- instance ---
variable "instance_name" {
  type    = string
  default = "ol9-herdr-dev"
}

# Always Free options (both are $0) as published on oracle.com/cloud/free (2026-09):
#   VM.Standard.E2.1.Micro  x86_64  1/8 OCPU, 1 GB RAM, up to 2 instances -- too small for LSPs + OpenCode
#   VM.Standard.A1.Flex     aarch64 "Ampere A1 cores and 12 GB of memory usable as 1 VM or 2 VMs"
#                           (1,500 OCPU-hours + 9,000 GB-hours per month = 2 OCPU / 12 GB continuously)
# Staying inside those numbers is what keeps the VM free; larger A1 sizes bill per hour.
variable "shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}
variable "shape_ocpus" {
  type    = number
  default = 2
}
variable "shape_memory_gb" {
  type    = number
  default = 12
}
variable "boot_volume_gb" {
  type    = number
  default = 100 # Always Free allows 200 GB of boot+block volumes in total
}
variable "os_version" {
  type    = string
  default = "9" # Oracle Linux 9 platform image
}

# --- access ---
variable "ssh_public_key" {
  type        = string
  description = "Contents of the public key allowed to SSH in as opc (e.g. file(\"~/.ssh/id_ed25519.pub\"))."
}
variable "ssh_source_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "Restrict SSH ingress to your own /32 when you have a static address."
}
