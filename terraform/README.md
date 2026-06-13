# terraform/ — Confluent Cloud destination (Dedicated cluster, private via PSC)

Provisions the **destination** for the zero-cut migration demo:

- a Confluent Cloud **environment** with **Schema Registry** (Stream Governance),
- a **PRIVATELINK network** = GCP **Private Service Connect** (one service attachment per
  zone) plus a **private link access** authorizing the source's GCP project,
- a **Dedicated** Kafka cluster landed in that network — Dedicated supports Cluster
  Linking (Basic/Standard do not), and PSC keeps the connection private (the source dials
  *out* to CC; CC never reaches into the source's VPC), and
- a **service account** and **API keys** (Kafka + Schema Registry) used by
  `kcp`, the cluster link, and the demo client.

> **What Terraform does NOT do.** PSC has a GCP side that lives in the *consumer* VPC:
> a PSC endpoint (forwarding rule) per zonal service attachment, and a private Cloud DNS
> zone that resolves the cluster's hostnames to those endpoints. Those are created
> out-of-band (the demo box's VM service account lacks compute scope) — see the
> `psc_service_attachments` / `dns_domain` outputs and the PSC step in `../MIGRATION.md`.
> Without the DNS override, clients resolve CC's *published broker IPs*, which are not
> routable from the consumer VPC.

> 💸 **Cost:** a Dedicated cluster bills **per CKU continuously** while it exists
> (a 1-CKU single-zone cluster is the cheapest demoable config). Run `terraform
> destroy` the moment the demo/recording is done. `SINGLE_ZONE` needs ≥ 1 CKU;
> `MULTI_ZONE` needs ≥ 2.

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

Tear down (deletes the Dedicated cluster — stops billing):

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
| `network_id` | the CC network (n-…) |
| `dns_domain` | the cluster's DNS domain — create the private Cloud DNS zone for `*.<domain>` |
| `psc_service_attachments` | map of zone → CC service attachment URI; point one PSC endpoint at each |
| `dotenv` | the whole block, ready to write to `../.env` |

The cluster link from the source to this cluster is created at demo time (see
`../MIGRATION.md`), since it depends on the live source. The GCP-side PSC endpoints + DNS
must be in place first (also in `../MIGRATION.md`).
