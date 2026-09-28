terraform {
  required_version = ">= 1.5.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.0"
    }
  }
}

# Authentication: ~/.oci/config profile (created by `oci setup config`) or the
# TF_VAR_* variables below. Never commit keys; see infra/terraform/README.md.
provider "oci" {
  region              = var.region
  tenancy_ocid        = var.tenancy_ocid
  user_ocid           = var.user_ocid
  fingerprint         = var.fingerprint
  private_key_path    = var.private_key_path
  config_file_profile = var.config_file_profile
}
