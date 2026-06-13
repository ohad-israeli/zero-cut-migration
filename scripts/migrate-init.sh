#!/usr/bin/env bash
# Wrapper for `kcp migration init`: validates the cluster link, mirror topics, and the
# initial/fenced/switchover Gateway CRs, then persists migration-state.json. Run once,
# after the cluster link exists and the INITIAL gateway CR is applied to k8s.
#
# The source's EXTERNAL listener is plaintext/unauthenticated -> --use-unauthenticated-plaintext
# (this describes how kcp connects to the source, not the source-initiated link to CC).
#
# Usage:  SOURCE_BOOTSTRAP=192.168.49.50:9094 ./migrate-init.sh   (source's minikube-net listener)
. "$(dirname "$0")/lib.sh"

[ -n "${SOURCE_BOOTSTRAP%:9094}" ] || { echo "set SOURCE_BOOTSTRAP=<host>:9094"; exit 1; }
fenced="$GATEWAY_DIR/gateway_fenced.yaml"
switch="$GATEWAY_DIR/gateway_switchover.yaml"
for f in "$fenced" "$switch"; do
  [ -f "$f" ] || { echo "missing $f — run gateway/render.sh first"; exit 1; }
done

kcp migration init \
  --k8s-namespace        "$K8S_NAMESPACE" \
  --initial-cr-name      "$INITIAL_CR_NAME" \
  --source-bootstrap     "$SOURCE_BOOTSTRAP" \
  --cluster-bootstrap    "$CC_BOOTSTRAP" \
  --cluster-id           "$CC_CLUSTER_ID" \
  --cluster-rest-endpoint "$CC_REST_ENDPOINT" \
  --cluster-link-name    "$LINK_NAME" \
  --cluster-api-key      "$CC_API_KEY" \
  --cluster-api-secret   "$CC_API_SECRET" \
  --fenced-cr-yaml       "$fenced" \
  --switchover-cr-yaml   "$switch" \
  --topics               "$DEMO_TOPIC" \
  --use-unauthenticated-plaintext

echo
echo "Initialized. List migrations with:  kcp migration list"
