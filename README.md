# zero-cut-migration

A hands-on demo of **zero-cut Kafka migration** — moving clients from a source Kafka
cluster to **Confluent Cloud with no client restarts**, built on **Confluent Cloud
Gateway + Cluster Linking + [KCP](https://github.com/confluentinc/kcp)** (Kafka Copy
Paste). The source here is **open-source Apache Kafka in Docker**, so the whole flow
runs without AWS MSK.

📝 Write-up: **https://ohad-israeli.github.io/projects/zero-cut-migration**

## The idea

Clients make **one** change — point their bootstrap at the **Gateway** — ahead of
time. Cluster Linking continuously replicates the topics (and syncs consumer
offsets) to a Confluent Cloud destination. When the operator runs **one** command
(`kcp migration execute`), KCP fences traffic, drains lag to zero, promotes the
mirror topics, and flips the Gateway route to Confluent Cloud — clients reconnect
transparently, no restarts.

## Layout

| Path | What |
|------|------|
| `terraform/` | Provisions the Confluent Cloud destination: an **Enterprise** cluster (required for Cluster Linking), Schema Registry, service account + API keys. |
| `docker-compose.yml` | Source: open-source Apache Kafka (KRaft) + a demo producer/consumer. *(added next)* |
| `gateway/` | Confluent Cloud Gateway CRs (initial / fenced / switchover) for minikube. *(added next)* |
| `scripts/` | Thin wrappers around `kcp migration init / lag-check / execute`. *(added next)* |
| `MIGRATION.md` | End-to-end runbook. *(added next)* |

## Status

🚧 Work in progress. The Confluent Cloud destination (`terraform/`) is in place —
start there. The source/Gateway/cutover pieces are being added; see the write-up for
the architecture.

## Requirements

- Docker + a Kubernetes runtime (minikube) for the Gateway.
- A **Confluent Cloud Enterprise (or Dedicated)** destination — `terraform/` creates it.
- The `kcp` CLI: <https://github.com/confluentinc/kcp>.

## License

MIT — see [LICENSE](LICENSE).
