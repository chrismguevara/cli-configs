# One VCN, one public subnet, an internet gateway, and a security list that
# admits nothing but SSH. Development ports (Vite, API, Keycloak, Postgres)
# bind to 127.0.0.1 on the VM and are reached through SSH local forwarding.

resource "oci_core_vcn" "dev" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.instance_name}-vcn"
  cidr_blocks    = ["10.42.0.0/16"]
  dns_label      = "devvcn"
}

resource "oci_core_internet_gateway" "dev" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.dev.id
  display_name   = "${var.instance_name}-igw"
  enabled        = true
}

resource "oci_core_route_table" "dev" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.dev.id
  display_name   = "${var.instance_name}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.dev.id
  }
}

resource "oci_core_security_list" "ssh_only" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.dev.id
  display_name   = "${var.instance_name}-ssh-only"

  # Outbound: everything (package repos, GitHub releases, npm, Go proxy).
  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }

  # Inbound: SSH only.
  ingress_security_rules {
    source      = var.ssh_source_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "6" # TCP
    tcp_options {
      min = 22
      max = 22
    }
  }

  # ICMP path-MTU discovery (recommended by Oracle; harmless).
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "1"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_subnet" "dev" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.dev.id
  display_name      = "${var.instance_name}-subnet"
  cidr_block        = "10.42.1.0/24"
  dns_label         = "dev"
  route_table_id    = oci_core_route_table.dev.id
  security_list_ids = [oci_core_security_list.ssh_only.id]
  # Public subnet: the instance gets an ephemeral public IP for SSH.
  prohibit_public_ip_on_vnic = false
}
