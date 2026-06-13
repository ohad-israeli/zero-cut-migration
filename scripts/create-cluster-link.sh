#!/usr/bin/env bash
# Create a SOURCE-INITIATED Cluster Link from the self-managed Confluent Server source
# to the Confluent Cloud destination, and mirror the demo topic. Source-initiated means
# the SOURCE dials OUT to Confluent Cloud — so this works even though the source sits in
# a VPC with no public inbound and Confluent Cloud is reached privately over PSC
# (Confluent Cloud never connects back to the source).
#
# Three steps (per Confluent's hybrid CP->CC runbook):
#   1. Destination link on CC   — link.mode=DESTINATION, connection.mode=INBOUND (REST).
#   2. Source link on cp-server — link.mode=SOURCE, connection.mode=OUTBOUND, dials CC's
#      bootstrap (resolved privately to the PSC endpoint) with the CC API key/secret.
#   3. Mirror topic on CC       — mirrors $DEMO_TOPIC from the source (REST).
#
# Usage:  scripts/create-cluster-link.sh
. "$(dirname "$0")/lib.sh"

SRC_CONTAINER="${SRC_CONTAINER:-cp-source}"
base="/kafka/v3/clusters/$CC_CLUSTER_ID/links"

# Source (CP) cluster id — referenced by the destination link.
CP_CLUSTER_ID="$(docker exec "$SRC_CONTAINER" kafka-cluster cluster-id --bootstrap-server cp-source:9092 \
  | awk -F': ' '/Cluster ID/{print $2}' | tr -d '[:space:]')"
[ -n "$CP_CLUSTER_ID" ] || { echo "could not read source cluster id"; exit 1; }
echo "==> source (CP) cluster id: $CP_CLUSTER_ID"

echo "==> [1/3] destination link '$LINK_NAME' on CC ($CC_CLUSTER_ID), INBOUND"
if cc_curl GET "$base/$LINK_NAME" -o /dev/null -w '%{http_code}' | grep -q '^200$'; then
  echo "    already exists"
else
  cc_curl POST "$base?link_name=$LINK_NAME" -d @- <<JSON
{
  "source_cluster_id": "$CP_CLUSTER_ID",
  "configs": [
    { "name": "link.mode", "value": "DESTINATION" },
    { "name": "connection.mode", "value": "INBOUND" },
    { "name": "consumer.offset.sync.enable", "value": "true" },
    { "name": "consumer.offset.sync.ms", "value": "1000" }
  ]
}
JSON
  echo "    created"
fi

echo "==> [2/3] source link '$LINK_NAME' on cp-server, OUTBOUND -> $CC_BOOTSTRAP"
docker exec -i "$SRC_CONTAINER" bash -s <<EOF
set -e
cat > /tmp/clusterlink-src.config <<CFG
link.mode=SOURCE
connection.mode=OUTBOUND
bootstrap.servers=$CC_BOOTSTRAP
ssl.endpoint.identification.algorithm=https
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username='$CC_API_KEY' password='$CC_API_SECRET';
local.listener.name=INTERNAL
local.security.protocol=PLAINTEXT
CFG
if kafka-cluster-links --bootstrap-server cp-source:9092 --list 2>/dev/null | grep -q '$LINK_NAME'; then
  echo "    already exists"
else
  kafka-cluster-links --bootstrap-server cp-source:9092 --create \
    --link '$LINK_NAME' --config-file /tmp/clusterlink-src.config --cluster-id '$CC_CLUSTER_ID'
fi
rm -f /tmp/clusterlink-src.config
EOF

echo "==> [3/3] mirror topic '$DEMO_TOPIC' on CC under link '$LINK_NAME'"
cc_curl POST "$base/$LINK_NAME/mirrors" -d "{\"source_topic_name\":\"$DEMO_TOPIC\"}" \
  -w '\n    http=%{http_code}\n' || true

echo "==> mirror status:"
cc_curl GET "$base/$LINK_NAME/mirrors" | sed 's/,/,\n/g' | grep -E 'mirror_topic_name|mirror_status|num_partitions' || true
echo
echo "Watch lag drain with:  scripts/lag-check.sh"
