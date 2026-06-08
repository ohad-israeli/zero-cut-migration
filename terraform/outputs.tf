output "environment_id" {
  value       = confluent_environment.this.id
  description = "Confluent Cloud environment ID."
}

output "cluster_id" {
  value       = confluent_kafka_cluster.enterprise.id
  description = "Destination Kafka cluster ID (lkc-...)."
}

output "cluster_bootstrap" {
  value       = replace(confluent_kafka_cluster.enterprise.bootstrap_endpoint, "SASL_SSL://", "")
  description = "Bootstrap server (host:9092), prefix stripped for kcp --cluster-bootstrap."
}

output "cluster_rest_endpoint" {
  value       = confluent_kafka_cluster.enterprise.rest_endpoint
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
    CC_CLUSTER_ID=${confluent_kafka_cluster.enterprise.id}
    CC_BOOTSTRAP=${replace(confluent_kafka_cluster.enterprise.bootstrap_endpoint, "SASL_SSL://", "")}
    CC_REST_ENDPOINT=${confluent_kafka_cluster.enterprise.rest_endpoint}
    CC_API_KEY=${confluent_api_key.cluster.id}
    CC_API_SECRET=${confluent_api_key.cluster.secret}
    CC_SR_URL=${data.confluent_schema_registry_cluster.sr.rest_endpoint}
    CC_SR_API_KEY=${confluent_api_key.schema_registry.id}
    CC_SR_API_SECRET=${confluent_api_key.schema_registry.secret}
  EOT
}
