#!/usr/bin/env bash
# Render the three Gateway CR templates into ./rendered/, substituting ${...} from
# ../.env (the Terraform-generated Confluent Cloud values) plus three gateway-specific
# variables you must set:
#
#   GATEWAY_IMAGE          the licensed CPC Gateway application image (Confluent
#                          Platform; requires a CP license + registry access).
#   GATEWAY_LB_HOST        the hostname/IP clients use as their bootstrap (the
#                          LoadBalancer address of the gateway), e.g. the minikube
#                          tunnel IP or an external DNS name.
#   SOURCE_BOOTSTRAP_HOST  host the Gateway + Cloud Cluster Link reach the source on
#                          (the box's public IP; TCP 9094 must be open).
#
# Usage:
#   export GATEWAY_IMAGE=... GATEWAY_LB_HOST=... SOURCE_BOOTSTRAP_HOST=...
#   ./render.sh
set -euo pipefail
cd "$(dirname "$0")"

[ -f ../.env ] && set -a && . ../.env && set +a

: "${CC_BOOTSTRAP:?set CC_BOOTSTRAP (or create ../.env from terraform output)}"
: "${GATEWAY_IMAGE:?set GATEWAY_IMAGE to the licensed CPC Gateway image}"
: "${GATEWAY_LB_HOST:?set GATEWAY_LB_HOST to the gateway LoadBalancer host}"
: "${SOURCE_BOOTSTRAP_HOST:?set SOURCE_BOOTSTRAP_HOST to the source broker public host}"

mkdir -p rendered
for f in gateway_init gateway_fenced gateway_switchover; do
  envsubst '${GATEWAY_IMAGE} ${GATEWAY_LB_HOST} ${SOURCE_BOOTSTRAP_HOST} ${CC_BOOTSTRAP}' \
    < "$f.yaml" > "rendered/$f.yaml"
  echo "rendered/$f.yaml"
done
