# ------------------------------------------------------------------------------
# Destination for the zero-cut migration demo: a Confluent Cloud environment with
# Schema Registry (Stream Governance) and an ENTERPRISE Kafka cluster. Enterprise
# is required because Cluster Linking for this flow does not support Basic/Standard.
# Plus a service account + API keys for kcp, the cluster link, and the demo client.
# ------------------------------------------------------------------------------

resource "confluent_environment" "this" {
  display_name = var.environment_name

  stream_governance {
    package = var.stream_governance_package
  }
}

resource "confluent_kafka_cluster" "enterprise" {
  display_name = var.cluster_name
  availability = var.availability
  cloud        = var.cloud
  region       = var.region

  enterprise {}

  environment {
    id = confluent_environment.this.id
  }
}

# Service account that owns the API keys (cluster link, mirror topics, demo client).
resource "confluent_service_account" "app" {
  display_name = "${var.cluster_name}-sa"
  description  = "Zero-cut migration demo service account"
}

# CloudClusterAdmin covers creating the cluster link, promoting mirror topics,
# and the demo client's produce/consume on the destination cluster.
resource "confluent_role_binding" "app_cluster_admin" {
  principal   = "User:${confluent_service_account.app.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.enterprise.rbac_crn
}

resource "confluent_api_key" "cluster" {
  display_name = "${var.cluster_name}-cluster-key"
  description  = "Kafka API key for the destination Enterprise cluster"

  owner {
    id          = confluent_service_account.app.id
    api_version = confluent_service_account.app.api_version
    kind        = confluent_service_account.app.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.enterprise.id
    api_version = confluent_kafka_cluster.enterprise.api_version
    kind        = confluent_kafka_cluster.enterprise.kind
    environment {
      id = confluent_environment.this.id
    }
  }

  # Let the role binding settle before the data-plane key is exercised.
  depends_on = [confluent_role_binding.app_cluster_admin]
}

# Schema Registry is auto-provisioned for the environment once Stream Governance
# is enabled above.
data "confluent_schema_registry_cluster" "sr" {
  environment {
    id = confluent_environment.this.id
  }
  depends_on = [confluent_kafka_cluster.enterprise]
}

resource "confluent_role_binding" "app_sr" {
  principal   = "User:${confluent_service_account.app.id}"
  role_name   = "DeveloperManage"
  crn_pattern = "${data.confluent_schema_registry_cluster.sr.resource_name}/subject=*"
}

resource "confluent_api_key" "schema_registry" {
  display_name = "${var.cluster_name}-sr-key"
  description  = "Schema Registry API key"

  owner {
    id          = confluent_service_account.app.id
    api_version = confluent_service_account.app.api_version
    kind        = confluent_service_account.app.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.sr.id
    api_version = data.confluent_schema_registry_cluster.sr.api_version
    kind        = data.confluent_schema_registry_cluster.sr.kind
    environment {
      id = confluent_environment.this.id
    }
  }

  depends_on = [confluent_role_binding.app_sr]
}
