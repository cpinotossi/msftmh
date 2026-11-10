#!/usr/bin/env bash
set -euo pipefail
for name in TEST_ODAA_SUBSCRIPTION_ID TEST_WORKSHOP_SUBSCRIPTION_ID TEST_DB_ID TEST_DB_SHAPE \
  TEST_DB_VERSION TEST_DB_COMPUTE_MODEL TEST_DB_COMPUTE TEST_DB_STORAGE \
  TEST_NETWORK_ANCHOR_ID TEST_RESOURCE_ANCHOR_ID TEST_DB_IP \
  TEST_ODAA_RG TEST_ODAA_VNET TEST_VM_RESOURCE_GROUP TEST_VM_VNET_NAME TEST_HUB_VNET_ID \
  TEST_FIREWALL_PRIVATE_IP TEST_HUB_RESOLVER_INBOUND_IP \
  TEST_ORACLE_DNS_DOMAIN TEST_ORACLE_DNS_ZONE_ID \
  TEST_CENTRAL_DNS_ZONE_NAME TEST_ODAA_DELEGATED_CIDR \
  TEST_DB_PORT TEST_DB_SERVICE TEST_DB_PDB TEST_DB_HOST; do
  [[ -n "$(printenv "$name")" ]] || { echo "Missing required test configuration: $name" >&2; exit 1; }
done
command -v bats >/dev/null
command -v dig >/dev/null
python3 -c 'import oracledb' >/dev/null
[[ -r /etc/oracle-workshop/base-db-test.json ]] || {
  echo 'Missing securely provisioned SQL credentials: /etc/oracle-workshop/base-db-test.json' >&2
  exit 1
}
az login --identity --allow-no-subscriptions >/dev/null
cd "$(dirname "$0")"
bats --tap challenge-*.bats
