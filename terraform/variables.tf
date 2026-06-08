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

variable "environment_name" {
  type        = string
  default     = "zero-cut-migration"
  description = "Display name for the Confluent Cloud environment."
}

variable "cluster_name" {
  type        = string
  default     = "zerocut-dest"
  description = "Display name for the destination Enterprise cluster."
}

variable "cloud" {
  type        = string
  default     = "AWS"
  description = "Cloud provider for the cluster: AWS, AZURE, or GCP."
}

variable "region" {
  type        = string
  default     = "us-east-2"
  description = "Cloud region (must support Enterprise clusters)."
}

variable "availability" {
  type        = string
  default     = "HIGH"
  description = "Enterprise clusters require HIGH (multi-zone); Confluent Cloud rejects SINGLE_ZONE for Enterprise."
  validation {
    condition     = var.availability == "HIGH"
    error_message = "Enterprise clusters must use availability = HIGH (multi-zone)."
  }
}

variable "stream_governance_package" {
  type        = string
  default     = "ESSENTIALS"
  description = "Stream Governance / Schema Registry package: ESSENTIALS or ADVANCED."
}
