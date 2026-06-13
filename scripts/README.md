# scripts/ — cluster link + kcp migration wrappers

Thin wrappers that read `../.env` (the Terraform output) so you don't retype cluster
IDs, endpoints, and keys. All are idempotent to re-run where it's safe.

| Script | Wraps | Does |
|--------|-------|------|
| `create-cluster-link.sh` | CC Kafka REST API + `kafka-cluster-links` | Creates the **source-initiated** Cluster Link (INBOUND link on CC + OUTBOUND link on cp-server) + the mirror topic, with consumer-offset sync on. |
| `migrate-init.sh` | `kcp migration init` | Validates the link, mirror topics, and the 3 Gateway CRs; writes `migration-state.json`. |
| `lag-check.sh` | `kcp migration lag-check` | Live TUI of mirror lag — run until ~0. |
| `migrate-execute.sh` | `kcp migration execute` | The cutover: fence → promote at zero lag → switch gateway to CC. |
| `lib.sh` | — | Shared: loads `../.env`, defines `cc_curl`, sets `LINK_NAME` / `DEMO_TOPIC` / etc. |

`SOURCE_BOOTSTRAP` is the source's EXTERNAL listener as **kcp** reaches it (its address on
the minikube docker network, e.g. `192.168.49.50:9094`), required by `migrate-init.sh`.
The link is source-initiated, so Confluent Cloud never connects back to the source.

See `../MIGRATION.md` for the full order of operations.
