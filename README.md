# zero-cut-migration

A hands-on demo of **zero-cut Kafka migration** — moving clients from a self-managed
Kafka cluster to **Confluent Cloud with no client restarts**, built on the
**CPC Gateway + Cluster Linking + [KCP](https://github.com/confluentinc/kcp)** (Kafka
Copy Paste). The source is a **self-managed Confluent Server in Docker**, so the whole
flow runs on one box without AWS MSK.

> **Why Confluent Server, not plain Apache Kafka?** The replication leg is a
> **source-initiated** Cluster Link: the source dials **outbound** to Confluent Cloud.
> That's what makes this work from behind a firewall that blocks inbound (Confluent
> Cloud never connects back to the source) — and Cluster Linking is a Confluent Server
> capability. It stands in for any self-managed CP / MSK-style cluster you'd migrate off.

📝 Write-up: **https://ohad-israeli.github.io/projects/zero-cut-migration**

## The idea

Clients make **one** change — point their bootstrap at the **Gateway** — ahead of
time. A source-initiated Cluster Link continuously replicates the topics (and syncs
consumer offsets) to a Confluent Cloud destination. When the operator runs **one**
command (`kcp migration execute`), KCP drains lag to zero, fences traffic, promotes the
mirror topics, and flips the Gateway route to Confluent Cloud — clients reconnect
transparently to the same endpoint, no restarts.

## Layout

| Path | What |
|------|------|
| `terraform/` | Provisions the Confluent Cloud destination: a **Dedicated** cluster on **private networking (GCP Private Service Connect)** — supports Cluster Linking and is reached privately from the source's VPC, Schema Registry, service account + API keys. |
| `docker-compose.yml` | Source: self-managed **Confluent Server** (KRaft, single node), with Cluster Linking enabled. |
| `client/` | Demo producer/consumer that prove zero-cut — point them at the Gateway and leave them running across the cutover. |
| `gateway/` | CPC Gateway CRs (initial / fenced / switchover) + render/secrets scripts for minikube. |
| `scripts/` | Source-initiated cluster-link creator + thin wrappers around `kcp migration init / lag-check / execute`. |
| `MIGRATION.md` | End-to-end operator runbook (the exact path this demo was validated on). |

## Status

🚧 Work in progress, but the full scaffold is in place: **`MIGRATION.md`** walks the
cutover end to end. Start with `terraform/` (the Confluent Cloud destination), then
follow the runbook.

## Requirements

- Docker + a Kubernetes runtime (minikube) for the Gateway.
- A **Confluent Cloud Dedicated** destination on **private networking (GCP PSC)** — `terraform/`
  creates the CC side; the GCP-side PSC endpoint + a private Cloud DNS zone are a one-time
  out-of-band step (see `terraform/README.md`).
- **Confluent for Kubernetes** (CFK ≥ 3.2, ships the `Gateway` CRD) and the **CPC Gateway
  image** `confluentinc/cpc-gateway` — both pull anonymously from Docker Hub; the gateway
  runs under a Confluent Platform **evaluation** license (no entitlement needed to try it).
- The `kcp` CLI ≥ 0.8: <https://github.com/confluentinc/kcp>.

Validated on a single GCP box: CFK 3.2.2, cpc-gateway 1.2.0, cp-server 7.7.1, kcp 0.8.1.

## License

MIT — see [LICENSE](LICENSE).
