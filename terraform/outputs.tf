output "environment_id" {
  value       = confluent_environment.this.id
  description = "Confluent Cloud environment ID."
}

output "cluster_id" {
  value       = confluent_kafka_cluster.dedicated.id
  description = "Destination Kafka cluster ID (lkc-...)."
}

# --- Private networking (Private Service Connect) -------------------------------
output "network_id" {
  value       = confluent_network.this.id
  description = "Confluent Cloud network ID (n-...)."
}

output "dns_domain" {
  value       = confluent_network.this.dns_domain
  description = "CC network DNS domain (e.g. <id>.us-east1.gcp.confluent.cloud). Create a private Cloud DNS zone for *.<domain> -> the PSC endpoint IP."
}

output "psc_service_attachments" {
  value       = confluent_network.this.gcp[0].private_service_connect_service_attachments
  description = "Map of GCP zone -> CC service attachment URI. Point a PSC endpoint (forwarding rule) at each."
}

output "cluster_bootstrap" {
  value       = replace(confluent_kafka_cluster.dedicated.bootstrap_endpoint, "SASL_SSL://", "")
  description = "Bootstrap server (host:9092), prefix stripped for kcp --cluster-bootstrap."
}

output "cluster_rest_endpoint" {
  value       = confluent_kafka_cluster.dedicated.rest_endpoint
  description = "Kafka REST endpoint (for kcp --cluster-rest-endpoint)."
}

output "schema_registry_url" {
  value       = data.confluent_schema_registry_cluster.sr.rest_endpoint
  description = "Schema Registry endpoint."
}

# Sensitive credential outputs (view with: terraform output -raw <name>)
output "cluster_api_key" {
  value     = confluent_api_key.cluster.id
  sensitive = true
}
output "cluster_api_secret" {
  value     = confluent_api_key.cluster.secret
  sensitive = true
}
output "schema_registry_api_key" {
  value     = confluent_api_key.schema_registry.id
  sensitive = true
}
output "schema_registry_api_secret" {
  value     = confluent_api_key.schema_registry.secret
  sensitive = true
}

# Convenience: append the demo's .env in one shot:
#   terraform output -raw dotenv >> ../.env
output "dotenv" {
  sensitive = true
  value     = <<-EOT
    CC_ENVIRONMENT_ID=${confluent_environment.this.id}
    CC_CLUSTER_ID=${confluent_kafka_cluster.dedicated.id}
    CC_BOOTSTRAP=${replace(confluent_kafka_cluster.dedicated.bootstrap_endpoint, "SASL_SSL://", "")}
    CC_REST_ENDPOINT=${confluent_kafka_cluster.dedicated.rest_endpoint}
    CC_API_KEY=${confluent_api_key.cluster.id}
    CC_API_SECRET=${confluent_api_key.cluster.secret}
    CC_SR_URL=${data.confluent_schema_registry_cluster.sr.rest_endpoint}
    CC_SR_API_KEY=${confluent_api_key.schema_registry.id}
    CC_SR_API_SECRET=${confluent_api_key.schema_registry.secret}
  EOT
}
