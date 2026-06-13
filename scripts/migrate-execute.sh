#!/usr/bin/env bash
# Wrapper for `kcp migration execute`: the actual zero-cut cutover. Resumable — it
# drains lag below the threshold, fences the gateway, promotes the mirror topics at
# zero lag, then switches the gateway route to Confluent Cloud. Clients on the gateway
# endpoint never restart.
#
# Pass the migration id (from `kcp migration list`) and a lag threshold (sum of all
# partition lags) it must reach before cutting over.
#
# Usage:  MIGRATION_ID=<id> [LAG_THRESHOLD=0] ./migrate-execute.sh
. "$(dirname "$0")/lib.sh"

: "${MIGRATION_ID:?set MIGRATION_ID (see: kcp migration list)}"
LAG_THRESHOLD="${LAG_THRESHOLD:-0}"

kcp migration execute \
  --migration-id      "$MIGRATION_ID" \
  --lag-threshold     "$LAG_THRESHOLD" \
  --cluster-api-key   "$CC_API_KEY" \
  --cluster-api-secret "$CC_API_SECRET" \
  --use-unauthenticated-plaintext

echo
echo "Cutover complete. Clients on the gateway are now served by Confluent Cloud ($CC_CLUSTER_ID)."
