#!/usr/bin/env bash
# Shared config for the migration scripts. Loads ../.env (written by
# `terraform output -raw dotenv > ../.env`) and sets the demo-wide knobs.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

if [ -f "$ROOT/.env" ]; then
  set -a; . "$ROOT/.env"; set +a
else
  echo "missing $ROOT/.env — run: (cd terraform && terraform output -raw dotenv > ../.env)" >&2
  exit 1
fi

# Confluent Cloud destination (from terraform output)
: "${CC_CLUSTER_ID:?}" "${CC_BOOTSTRAP:?}" "${CC_REST_ENDPOINT:?}" "${CC_API_KEY:?}" "${CC_API_SECRET:?}"

# Demo-wide knobs (override via env)
LINK_NAME="${LINK_NAME:-zerocut-link}"
DEMO_TOPIC="${DEMO_TOPIC:-orders}"
K8S_NAMESPACE="${K8S_NAMESPACE:-confluent}"
INITIAL_CR_NAME="${INITIAL_CR_NAME:-migration-gateway}"
GATEWAY_DIR="${GATEWAY_DIR:-$ROOT/gateway/rendered}"

# The source's EXTERNAL listener, as kcp and the Gateway pods reach it (its address on
# the minikube docker network, e.g. 192.168.49.50:9094). Used by `kcp migration init`.
# Note: the cluster link is source-initiated, so Confluent Cloud never connects here.
SOURCE_BOOTSTRAP="${SOURCE_BOOTSTRAP:-${SOURCE_BOOTSTRAP_HOST:-}:9094}"

cc_curl() {
  # cc_curl METHOD PATH [curl-args...]   (PATH is relative to the Kafka REST endpoint)
  local method="$1" path="$2"; shift 2
  curl -sS -u "$CC_API_KEY:$CC_API_SECRET" -X "$method" \
    -H "Content-Type: application/json" "$CC_REST_ENDPOINT$path" "$@"
}
