# ------------------------------------------------------------------------------
# Destination for the zero-cut migration demo: a Confluent Cloud environment with
# Schema Registry (Stream Governance) and a DEDICATED Kafka cluster reachable over
# PRIVATE networking via GCP Private Service Connect (PSC).
#
# Why PSC and not VPC peering: the demo box lives in a Confluent-OWNED GCP project
# (sales-engineering-206314, org confluent.io). Confluent Cloud's peering API refuses
# to VPC-peer into one of its own projects ("can not use Confluent project id"). PSC
# reverses the direction — the customer VPC dials OUT to Confluent's service
# attachment — so Confluent never provisions anything inside our project, and the
# project-ownership check doesn't apply.
#
# Because PSC is consumer->producer only (the box reaches CC, never the reverse), the
# replication leg is a SOURCE-INITIATED Cluster Link: the self-managed Confluent Server
# source dials OUT to this CC cluster's bootstrap, resolved privately to the PSC
# endpoint IP. That also matches the box's firewall (outbound allowed, no public inbound).
#
# The CC-side resources (network, private link access, cluster, keys) are managed here
# with the Confluent provider. The GCP-side PSC endpoint (address + forwarding rule) and
# the Cloud DNS private zone are created out-of-band from a machine with GCP compute
# creds (the box's VM service account lacks compute scope) — see outputs for the values.
# ------------------------------------------------------------------------------

resource "confluent_environment" "this" {
  display_name = var.environment_name

  stream_governance {
    package = var.stream_governance_package
  }
}

# PRIVATELINK network = GCP Private Service Connect. CC provisions a service attachment
# per zone; we point PSC endpoints at them and resolve CC's dns_domain to those IPs.
resource "confluent_network" "this" {
  display_name     = "${var.cluster_name}-net"
  cloud            = var.cloud
  region           = var.region
  connection_types = ["PRIVATELINK"]
  zones            = var.zones

  dns_config {
    resolution = "PRIVATE"
  }

  environment {
    id = confluent_environment.this.id
  }
}

# Authorizes our GCP project's PSC endpoints to connect to the service attachment.
# Unlike peering, this does NOT make CC create anything in our project, so the
# Confluent-owned-project restriction does not apply here.
resource "confluent_private_link_access" "gcp" {
  display_name = "${var.cluster_name}-pla"

  gcp {
    project = var.gcp_project
  }

  network {
    id = confluent_network.this.id
  }

  environment {
    id = confluent_environment.this.id
  }
}

resource "confluent_kafka_cluster" "dedicated" {
  display_name = var.cluster_name
  availability = var.availability
  cloud        = var.cloud
  region       = var.region

  dedicated {
    cku = var.cku
  }

  environment {
    id = confluent_environment.this.id
  }

  # Land the cluster in the PSC network. depends_on the private link access so the
  # endpoint authorization is in place before the cluster is exercised.
  network {
    id = confluent_network.this.id
  }

  depends_on = [confluent_private_link_access.gcp]
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
  crn_pattern = confluent_kafka_cluster.dedicated.rbac_crn
}

resource "confluent_api_key" "cluster" {
  display_name = "${var.cluster_name}-cluster-key"
  description  = "Kafka API key for the destination Dedicated cluster"

  owner {
    id          = confluent_service_account.app.id
    api_version = confluent_service_account.app.api_version
    kind        = confluent_service_account.app.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.dedicated.id
    api_version = confluent_kafka_cluster.dedicated.api_version
    kind        = confluent_kafka_cluster.dedicated.kind
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
  depends_on = [confluent_kafka_cluster.dedicated]
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
