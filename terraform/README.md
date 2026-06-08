# terraform/ — Confluent Cloud destination (Enterprise cluster)

Provisions the **destination** for the zero-cut migration demo:

- a Confluent Cloud **environment** with **Schema Registry** (Stream Governance), and
- an **Enterprise** Kafka cluster — required because Cluster Linking for this flow
  does **not** support Basic/Standard clusters,
- plus a **service account** and **API keys** (Kafka + Schema Registry) used by
  `kcp`, the cluster link, and the demo client.

> 💸 **Cost:** an Enterprise cluster bills hourly (and per usage). Run `terraform
> destroy` when you're done. `availability = "SINGLE_ZONE"` (the default) is the
> cheaper option; set `HIGH` for multi-AZ.

## Prerequisites

- Terraform ≥ 1.3.
- A Confluent Cloud **Cloud API key** (resource-management key) able to create
  environments + clusters — OrganizationAdmin is simplest. Create one in the CC
  Console (Administration → API keys → "Cloud resource management").

## Use

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # then edit it
#   (or: export CONFLUENT_CLOUD_API_KEY=...  CONFLUENT_CLOUD_API_SECRET=...)

terraform init
terraform plan
terraform apply
```

Feed the outputs into the demo's `.env` in one shot:

```bash
terraform output -raw dotenv >> ../.env
```

Individual sensitive values:

```bash
terraform output -raw cluster_api_secret
terraform output -raw schema_registry_api_secret
```

Tear down (deletes the Enterprise cluster — stops billing):

```bash
terraform destroy
```

## Outputs

| Output | Use |
|--------|-----|
| `cluster_bootstrap` | `kcp migration init --cluster-bootstrap` (SASL_SSL:// prefix already stripped) |
| `cluster_id` | `--cluster-id` (lkc-…) |
| `cluster_rest_endpoint` | `--cluster-rest-endpoint` |
| `cluster_api_key` / `cluster_api_secret` | `--cluster-api-key/secret` and the demo client |
| `schema_registry_url` / `schema_registry_api_key` / `_secret` | Avro, if the client uses it |
| `dotenv` | the whole block, ready to append to `../.env` |

The cluster link from the source Kafka to this cluster is created at demo time (see
`../MIGRATION.md`), since it depends on the live source bootstrap.
