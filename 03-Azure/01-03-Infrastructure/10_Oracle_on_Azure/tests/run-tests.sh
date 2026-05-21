#!/usr/bin/env bash
# Run all BATS challenge tests
# Usage: ./run-tests.sh [user_index]
# Env: TEST_MH0_SUB, TEST_MHODAA_SUB (set by pipeline via run-command)
set -euo pipefail

export TEST_USER_INDEX="${1:-00}"
export TEST_RG="rg-vm-user${TEST_USER_INDEX}"
export TEST_VM="vm-user${TEST_USER_INDEX}"
export TEST_VNET="vnet-vm-user${TEST_USER_INDEX}"
export TEST_DNS_ZONE="adb.eu-paris-1.oraclecloud.com"

echo "============================================"
echo "Workshop Challenge Tests"
echo "============================================"
echo "User Index: $TEST_USER_INDEX"
echo "MH0 Sub:    $TEST_MH0_SUB"
echo "MHODAA Sub: $TEST_MHODAA_SUB"
echo "============================================"
echo ""

# Wait for BATS to be available
for i in $(seq 1 30); do
  command -v bats &>/dev/null && break
  echo "Waiting for BATS installation... ($i/30)"
  sleep 10
done

if ! command -v bats &>/dev/null; then
  echo "ERROR: BATS not available after 5 minutes"
  exit 1
fi

# Login with managed identity
az login --identity --allow-no-subscriptions >/dev/null 2>&1

# Run tests
cd /opt/tests
bats --tap challenge-*.bats
