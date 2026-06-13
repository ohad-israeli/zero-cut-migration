# MIGRATION.md — zero-cut cutover, end to end

The operator runbook for moving live clients from a **self-managed Confluent Server**
cluster to **Confluent Cloud** with **no client restarts**, using a **CPC Gateway** as
the stable client endpoint and **source-initiated Cluster Linking** to pre-replicate the
data. This is the exact path the demo was validated on (CFK 3.2.2, cpc-gateway 1.2.0,
cp-server 7.7.1, kcp 0.8.1).

The shape of it: clients connect to the Gateway (not a broker). A source-initiated
Cluster Link copies topics + consumer offsets to Confluent Cloud in the background —
the **source dials out** to CC, so nothing needs to reach *into* the source. When lag
hits zero, `kcp migration execute` fences the Gateway for a moment, promotes the mirror
topics, and re-points the Gateway at Confluent Cloud — clients reconnect to the *same*
address and keep going.

```
                 ┌─────────────────────────── before ───────────────────────────┐
   clients ──▶ CPC Gateway ──▶  Confluent Server (source, Docker)
                                    │
                                    │  source-initiated Cluster Link (dials OUT to CC
                                    │  privately over PSC; mirrors topics + syncs
                                    ▼  consumer offsets)
                              Confluent Cloud  (lkc-…, Dedicated, private via GCP PSC)
                 └──────────────────────────── after ───────────────────────────┘
   clients ──▶ CPC Gateway ──▶  Confluent Cloud      (same client endpoint, no restart)
```

> **Why source-initiated?** Cluster Linking normally has the *destination* (CC) dial the
> source. If the source sits behind a firewall that blocks inbound, that can't work.
> A **source-initiated** link flips the direction — the source makes an **outbound**
> connection to CC — so only outbound internet from the source is required. Cluster
> Linking is a Confluent Server feature, which is why the source is `cp-server`, not
> plain Apache Kafka.

---

## 0. Prerequisites

- **Confluent Cloud destination** — provisioned by `terraform/` (Dedicated cluster
  `lkc-…` on **private networking via GCP PSC**, SR, service account + API keys). Export
  the values:
  ```bash
  cd terraform && terraform output -raw dotenv > ../.env
  ```
- **PSC reachability (one-time, out-of-band).** Terraform creates only the CC side
  (a PRIVATELINK network with a per-zone service attachment). On the GCP side you must,
  once, point a PSC endpoint at each service attachment and override DNS so the cluster's
  hostnames resolve to those endpoints — otherwise clients resolve CC's *published broker
  IPs*, which are unreachable. Using the `terraform output` values:
  ```bash
  DOMAIN=$(terraform output -raw dns_domain)            # e.g. dom8w100m4p.us-east1.gcp.confluent.cloud
  # 1. One PSC endpoint (forwarding rule) per zonal service attachment (see psc_service_attachments):
  #    gcloud compute forwarding-rules create psc-cc-zerocut-<z> --region=<region> \
  #      --network=<vpc> --subnet=<subnet> --target-service-attachment=<attachment-uri>
  # 2. A PRIVATE Cloud DNS zone for the cluster domain, bound to the source's VPC,
  #    with a wildcard A record to the PSC endpoint IP(s):
  gcloud dns managed-zones create zerocut-cc-psc --visibility=private \
    --networks=<vpc> --dns-name="$DOMAIN."
  gcloud dns record-sets create "*.$DOMAIN." --zone=zerocut-cc-psc \
    --type=A --ttl=60 --rrdatas="<psc-ip-1>,<psc-ip-2>,<psc-ip-3>"
  ```
  Verify from the source host: `getent hosts <bootstrap>` returns the PSC endpoint IPs and
  `nc -z <bootstrap> 9092` succeeds.
- **Docker**, and **minikube** running (`minikube start`) — the source container attaches
  to minikube's docker network so the in-cluster Gateway can reach it.
- **Confluent for Kubernetes (CFK) ≥ 3.2** (ships the `Gateway` CRD):
  ```bash
  helm repo add confluentinc https://packages.confluent.io/helm && helm repo update
  helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes \
    -n confluent --create-namespace
  ```
- **`kcp`** CLI ≥ 0.8 (`kcp migration --help`).
- Only **outbound** connectivity from the source to Confluent Cloud (TCP 9092, privately
  over the PSC endpoint) is required — no inbound. The CPC Gateway image
  (`confluentinc/cpc-gateway`) pulls anonymously and runs under a CP **evaluation** license.

---

## 1. Bring up the source + start traffic

```bash
docker compose up -d                     # cp-server (KRaft) on the minikube net @ 192.168.49.50; topic 'orders'
docker build -t zerocut-client ./client
```

Start the long-running demo clients pointed at the **Gateway** once it's up (step 2) —
they should run untouched across the whole cutover. (For a quick pre-Gateway smoke test,
point `BOOTSTRAP` straight at the source's external listener `192.168.49.50:9094`.)

## 2. Deploy the CPC Gateway (initial → source)

```bash
export GATEWAY_IMAGE=confluentinc/cpc-gateway:1.2.0
export GATEWAY_LB_HOST=$(minikube ip)                  # node IP; used in the route/advertised host
export SOURCE_BOOTSTRAP_HOST=192.168.49.50             # source EXTERNAL listener on the minikube net
cd gateway && ./render.sh && cd ..

kubectl create namespace confluent 2>/dev/null || true
NAMESPACE=confluent gateway/secrets.sh                 # CC auth secrets for the switchover CR
kubectl apply -n confluent -f gateway/rendered/gateway_init.yaml
kubectl -n confluent wait --for=jsonpath='{.status.phase}'=RUNNING gateway/migration-gateway --timeout=300s
```

The Gateway becomes Ready and proxies `clients → source` (its log shows
`Downstream <host>:9595 => Upstream [192.168.49.50:9094]`).

> **External client reachability (optional, for a live recording):** the Gateway is a
> `LoadBalancer` service; on minikube its EXTERNAL-IP stays `<pending>` until you run
> `minikube tunnel` (separate terminal, needs sudo). The cutover itself (below) does
> **not** need the tunnel — `kcp` drives the CRs and talks to CC directly. If you do want
> clients streaming through the Gateway, run the tunnel and set `GATEWAY_LB_HOST` to the
> assigned LB IP before rendering.

## 3. Create the source-initiated Cluster Link + mirror topic

```bash
scripts/create-cluster-link.sh
```

Creates the **INBOUND** destination link on CC, the **OUTBOUND** source link on
cp-server (dialing CC with the CC API key/secret), and the `orders` mirror — with
consumer-offset sync on. (The script also forces the single-broker
`_confluent-link-metadata` topic to `min.insync.replicas=1`.)

## 4. Initialize the migration

```bash
SOURCE_BOOTSTRAP=192.168.49.50:9094 scripts/migrate-init.sh
kcp migration list                       # note the MIGRATION_ID
```

Validates the link, the mirror topics, and the three Gateway CRs, then writes
`migration-state.json`.

## 5. Wait for zero lag

```bash
scripts/lag-check.sh                      # live TUI — wait until total lag ~0, then q
```

## 6. Execute the cutover

```bash
MIGRATION_ID=<id> LAG_THRESHOLD=0 scripts/migrate-execute.sh
```

`kcp` drains lag below the threshold → applies `gateway_fenced.yaml` (clients briefly
retry, they don't die) → promotes the mirror topics at zero lag → applies
`gateway_switchover.yaml` (Gateway now serves from Confluent Cloud). **Resumable:** re-run
the same command if interrupted. Expected tail:

```
✔ All topic lags below threshold (0)
🚧 Fencing gateway...        ✔ Gateway fenced and ready
📤 Promoting mirror topics... ✔ orders promoted
🔄 Switching gateway to Confluent Cloud... ✔ Gateway switchover complete
✅ Migration complete!   Status: switched
```

## 7. Verify zero-cut

- The Gateway log now shows `Downstream <host>:9595 => Upstream [lkc-….<domain>:9092]` —
  the same client endpoint is served by Confluent Cloud (over the PSC endpoint).
- The mirror's status is `STOPPED` (promoted), and `orders` on `lkc-…` is a normal,
  **writable** topic with current consumer-group offsets.
- Any client left running on the Gateway endpoint never restarted.

---

## Teardown (do this promptly — the Dedicated cluster bills continuously)

```bash
docker rm -f zerocut-producer zerocut-consumer 2>/dev/null || true
docker compose down -v
kubectl delete namespace confluent        # gateway + secrets
minikube delete

# Stop Confluent Cloud billing:
cd terraform && terraform destroy         # (export the CC creds first)

# Out-of-band GCP-side PSC plumbing (not managed by terraform):
gcloud dns managed-zones delete zerocut-cc-psc
gcloud compute forwarding-rules delete psc-cc-zerocut-b psc-cc-zerocut-c psc-cc-zerocut-d --region=<region>
```
