#!/usr/bin/env bash
# Wrapper for `kcp migration lag-check`: live TUI of mirror-topic lag for the cluster
# link. Run it until lag sits at ~0 before cutting over (q to quit, p partitions, r refresh).
#
# Usage:  ./lag-check.sh
. "$(dirname "$0")/lib.sh"

exec kcp migration lag-check \
  --rest-endpoint     "$CC_REST_ENDPOINT" \
  --cluster-id        "$CC_CLUSTER_ID" \
  --cluster-link-name "$LINK_NAME" \
  --cluster-api-key   "$CC_API_KEY" \
  --cluster-api-secret "$CC_API_SECRET"
