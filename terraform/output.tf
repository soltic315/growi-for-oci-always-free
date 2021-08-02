output "web_public_ip" {
  value = oci_core_instance.web.public_ip
}

output "elasticsearch_public_ip" {
  value = oci_core_instance.elasticsearch.public_ip
}

output "elasticsearch_private_ip" {
  value = oci_core_instance.elasticsearch.private_ip
}

output "access_key" {
  value = oci_identity_customer_secret_key.this.id
}

output "secret_key" {
  value = oci_identity_customer_secret_key.this.key
}
