# gateway/ — CPC Gateway custom resources (minikube / CFK)

The **Confluent Platform Connect (CPC) Gateway** is the piece that makes the cut
"zero": clients connect to it instead of to a broker, and it transparently re-points
from the source Kafka to Confluent Cloud during cutover. It is deployed as a
`kind: Gateway` (`platform.confluent.io/v1beta1`) custom resource, reconciled by
**Confluent for Kubernetes (CFK)**.

Three CRs model the lifecycle (all named `migration-gateway`, applied/swapped in place
so the client endpoint never changes):

| File | State | Route |
|------|-------|-------|
| `gateway_init.yaml` | initial | clients → **source** Confluent Server (auth: none, passthrough) |
| `gateway_fenced.yaml` | fenced | traffic blocked (`BROKER_NOT_AVAILABLE`) during the zero-lag promote |
| `gateway_switchover.yaml` | switchover | clients → **Confluent Cloud** (auth swapped to SASL/PLAIN via secret store) |

> **Prerequisite:** the `spec.image.application` gateway image (`confluentinc/cpc-gateway`)
> and CFK (which must be a build that ships the `Gateway` CRD — **CFK ≥ 3.2**) both pull
> **anonymously from Docker Hub**. The gateway starts under a Confluent Platform
> **evaluation** license, so you can run this end to end without an entitlement. Set
> `GATEWAY_IMAGE=confluentinc/cpc-gateway:1.2.0` (the version this demo was validated on).

## Use

```bash
# 1. Render templates with real values (reads ../.env for CC_BOOTSTRAP):
export GATEWAY_IMAGE=confluentinc/cpc-gateway:1.2.0
export GATEWAY_LB_HOST=<gateway-loadbalancer-host>     # e.g. the minikube node IP / tunnel IP
export SOURCE_BOOTSTRAP_HOST=192.168.49.50             # source's EXTERNAL listener on the minikube
                                                       # docker network (see ../docker-compose.yml)
./render.sh                                            # -> rendered/*.yaml

# 2. Create the namespace + CC auth secrets the switchover CR needs:
kubectl create namespace confluent
NAMESPACE=confluent ./secrets.sh

# 3. Apply the INITIAL CR (clients route to the source through the gateway):
kubectl apply -n confluent -f rendered/gateway_init.yaml

# 4. kcp drives the fenced + switchover CRs during `kcp migration execute`
#    (see ../scripts and ../MIGRATION.md). You pass it the file paths:
#      --initial-cr-name migration-gateway
#      --fenced-cr-yaml     rendered/gateway_fenced.yaml
#      --switchover-cr-yaml rendered/gateway_switchover.yaml
```

`rendered/` is gitignored — it contains substituted (non-secret, but environment-specific)
values.
