# Auth: a Confluent Cloud "Cloud" API key (resource-management key) with enough
# privilege to create an environment + Enterprise cluster (OrganizationAdmin is
# simplest). Provide via terraform.tfvars or env vars:
#   export CONFLUENT_CLOUD_API_KEY=...  CONFLUENT_CLOUD_API_SECRET=...
# (the provider also reads those env vars directly if the vars are left unset).
provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}
