data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# Latest Oracle Linux 9 platform image compatible with the chosen shape.
data "oci_core_images" "ol9" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = var.os_version
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  is_flex = can(regex("Flex$", var.shape))
  ad_name = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
}

resource "oci_core_instance" "dev" {
  compartment_id      = var.compartment_ocid
  availability_domain = local.ad_name
  display_name        = var.instance_name
  shape               = var.shape

  dynamic "shape_config" {
    for_each = local.is_flex ? [1] : []
    content {
      ocpus         = var.shape_ocpus
      memory_in_gbs = var.shape_memory_gb
    }
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ol9.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.dev.id
    assign_public_ip = true
    hostname_label   = "dev"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("${path.module}/cloud-init.yaml"))
  }

  # Recreating the boot volume on image updates would destroy the dev VM.
  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}
