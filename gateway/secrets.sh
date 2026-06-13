#!/usr/bin/env bash
# Create the Kubernetes secrets the SWITCHOVER Gateway CR needs to authenticate to
# Confluent Cloud, mapping the client's anonymous identity to the CC API key/secret:
#
#   tls                           — truststore so the Gateway trusts CC's TLS certs.
#   file-store-config             — the "/" separator for the file secret store.
#   file-store-noauth-credentials — maps ANONYMOUS -> "<api-key>/<api-secret>".
#   plain-jaas                    — the SASL/PLAIN JAAS template the Gateway fills in.
#
# Reads CC_API_KEY / CC_API_SECRET from ../.env (terraform output). Run once in the
# target namespace before `kcp migration execute`.
#
# Usage:  NAMESPACE=confluent ./secrets.sh
set -euo pipefail
cd "$(dirname "$0")"

[ -f ../.env ] && set -a && . ../.env && set +a
: "${CC_API_KEY:?set CC_API_KEY (terraform output)}"
: "${CC_API_SECRET:?set CC_API_SECRET (terraform output)}"
NS="${NAMESPACE:-confluent}"
JKS_PASSWORD="${JKS_PASSWORD:-changeit}"

# Truststore from the local JVM's CA bundle (CC uses public CAs).
CACERTS="${JAVA_HOME:-/usr/lib/jvm/default-java}/lib/security/cacerts"
[ -f "$CACERTS" ] || { echo "cacerts not found at $CACERTS — set JAVA_HOME"; exit 1; }
cp "$CACERTS" /tmp/ccloud-truststore.jks
echo "jksPassword=${JKS_PASSWORD}" > /tmp/ccloud-jksPassword.txt

kubectl create secret generic tls -n "$NS" \
  --from-file=truststore.jks=/tmp/ccloud-truststore.jks \
  --from-file=jksPassword.txt=/tmp/ccloud-jksPassword.txt \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic file-store-config -n "$NS" \
  --from-literal=separator="/" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic file-store-noauth-credentials -n "$NS" \
  --from-literal=ANONYMOUS="${CC_API_KEY}/${CC_API_SECRET}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic plain-jaas -n "$NS" \
  --from-literal=plain-jaas.conf='org.apache.kafka.common.security.plain.PlainLoginModule required username="%s" password="%s";' \
  --dry-run=client -o yaml | kubectl apply -f -

rm -f /tmp/ccloud-truststore.jks /tmp/ccloud-jksPassword.txt
echo "secrets created/updated in namespace '$NS'"
