terraform {
  required_providers {
    oci = {
      source  = "hashicorp/oci"
      version = "4.37.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = "ap-tokyo-1"
}

# Common Resource
resource "oci_core_vcn" "this" {
  cidr_block               = var.vcn_cidr_block
  compartment_id           = var.compartment_id
  default_security_list_id = null
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  enabled        = true
}

resource "oci_core_default_route_table" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_route_table_id

  route_rules {
    network_entity_id = oci_core_internet_gateway.this.id
    destination       = "0.0.0.0/0"
  }
}

resource "oci_core_default_security_list" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_security_list_id

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }
}

data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}

resource "oci_core_subnet" "this" {
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[0].name
  cidr_block          = var.subnet_cidr_block
  compartment_id      = var.compartment_id
  vcn_id              = oci_core_vcn.this.id
  route_table_id      = oci_core_default_route_table.this.id
}

resource "oci_core_network_security_group" "ssh" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
}

resource "oci_core_network_security_group_security_rule" "ssh" {
  network_security_group_id = oci_core_network_security_group.ssh.id
  protocol                  = "6" # ICMP ("1"), TCP ("6"), UDP ("17"), ICMPv6 ("58").
  direction                 = "INGRESS"
  source                    = var.ssh_source_cidr
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# Web Resource
resource "oci_core_network_security_group" "web" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
}

resource "oci_core_network_security_group_security_rule" "http" {
  network_security_group_id = oci_core_network_security_group.web.id
  protocol                  = "6" # ICMP ("1"), TCP ("6"), UDP ("17"), ICMPv6 ("58").
  direction                 = "INGRESS"
  source                    = "0.0.0.0/0"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "https" {
  network_security_group_id = oci_core_network_security_group.web.id
  protocol                  = "6" # ICMP ("1"), TCP ("6"), UDP ("17"), ICMPv6 ("58").
  direction                 = "INGRESS"
  source                    = "0.0.0.0/0"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_instance" "web" {
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[0].name
  compartment_id      = var.compartment_id
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.this.id
    assign_public_ip = true
    nsg_ids          = [oci_core_network_security_group.web.id, oci_core_network_security_group.ssh.id]
  }

  source_details {
    source_type = "image"
    source_id   = "ocid1.image.oc1.ap-tokyo-1.aaaaaaaabns3667qll4wvmjftjkuozjk57dwjd2txsurk5prd4frljbwigiq"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_authorized_keys
  }
}

# Elasticsearch Resource
resource "oci_core_network_security_group" "elasticsearch" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
}

resource "oci_core_network_security_group_security_rule" "elasticsearch" {
  network_security_group_id = oci_core_network_security_group.elasticsearch.id
  protocol                  = "6" # ICMP ("1"), TCP ("6"), UDP ("17"), ICMPv6 ("58").
  direction                 = "INGRESS"
  source                    = "${oci_core_instance.web.private_ip}/32"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 9200
      max = 9200
    }
  }
}

resource "oci_core_instance" "elasticsearch" {
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[0].name
  compartment_id      = var.compartment_id
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.this.id
    assign_public_ip = true
    nsg_ids          = [oci_core_network_security_group.elasticsearch.id, oci_core_network_security_group.ssh.id]
  }

  source_details {
    source_type = "image"
    source_id   = "ocid1.image.oc1.ap-tokyo-1.aaaaaaaabns3667qll4wvmjftjkuozjk57dwjd2txsurk5prd4frljbwigiq"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_authorized_keys
  }
}

# ObjectStorage Resource
resource "oci_objectstorage_bucket" "this" {
  compartment_id = var.compartment_id
  name           = "growi"
  namespace      = var.bucket_namespace
}

resource "oci_identity_user" "this" {
  compartment_id = var.tenancy_ocid
  description    = "growi"
  name           = "growi"
}

resource "oci_identity_customer_secret_key" "this" {
  display_name = "growi"
  user_id      = oci_identity_user.this.id
}