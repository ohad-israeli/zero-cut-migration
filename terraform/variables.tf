variable "confluent_cloud_api_key" {
  type        = string
  sensitive   = true
  description = "Confluent Cloud API key (Cloud/resource-management key, e.g. OrganizationAdmin)."
}

variable "confluent_cloud_api_secret" {
  type        = string
  sensitive   = true
  description = "Confluent Cloud API secret."
}

# --- Private networking (GCP Private Service Connect) ---------------------------
variable "zones" {
  type        = list(string)
  default     = ["us-east1-b", "us-east1-c", "us-east1-d"]
  description = "GCP zones for the Confluent Cloud PSC network. CC requires THREE zones for a GCP PSC network even when the cluster is SINGLE_ZONE; one PSC endpoint is created per zone. Must be valid zones in var.region."
}

variable "gcp_project" {
  type        = string
  default     = "sales-engineering-206314"
  description = "GCP project ID whose PSC endpoints are authorized to reach the CC service attachment (the customer project hosting ohad-vpc / the demo box)."
}

variable "gcp_vpc_network" {
  type        = string
  default     = "ohad-vpc"
  description = "Customer GCP VPC network that hosts the PSC endpoint (referenced when creating the GCP-side endpoint + DNS out-of-band)."
}

variable "gcp_subnetwork" {
  type        = string
  default     = "ohad-vpc-sub1"
  description = "Customer subnetwork (in var.region) where the PSC endpoint internal IP is allocated."
}

variable "environment_name" {
  type        = string
  default     = "zero-cut-migration"
  description = "Display name for the Confluent Cloud environment."
}

variable "cluster_name" {
  type        = string
  default     = "zerocut-dest"
  description = "Display name for the destination Dedicated cluster."
}

variable "cloud" {
  type        = string
  default     = "GCP"
  description = "Cloud provider for the cluster: AWS, AZURE, or GCP."
}

variable "region" {
  type        = string
  default     = "us-east1"
  description = "Cloud region (GCP us-east1 matches the GCP demo box for lowest latency)."
}

variable "availability" {
  type        = string
  default     = "SINGLE_ZONE"
  description = "SINGLE_ZONE (1 CKU min) is cheapest for the demo; MULTI_ZONE needs >= 2 CKU."
  validation {
    condition     = contains(["SINGLE_ZONE", "MULTI_ZONE"], var.availability)
    error_message = "availability must be SINGLE_ZONE or MULTI_ZONE."
  }
}

variable "cku" {
  type        = number
  default     = 1
  description = "Confluent Kafka Units for the Dedicated cluster. SINGLE_ZONE minimum is 1; MULTI_ZONE minimum is 2."
  validation {
    condition     = var.cku >= 1
    error_message = "cku must be >= 1."
  }
}

variable "stream_governance_package" {
  type        = string
  default     = "ESSENTIALS"
  description = "Stream Governance / Schema Registry package: ESSENTIALS or ADVANCED."
}
