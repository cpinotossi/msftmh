#!/usr/bin/env bash
# Run all BATS challenge tests (standalone — no user VM dependency)
# Env: TEST_MH0_SUB, TEST_MHODAA_SUB, TEST_MHCORE_SUB, TEST_ADB_NAME (set by pipeline)
set -euo pipefail

# Load Oracle environment (rwloadsim, instant client, etc.)
# Needed because az vm run-command uses non-login shell (no /etc/profile.d/)
source /etc/profile.d/oracle-workshop.sh 2>/dev/null || true

export TEST_DNS_RG="${TEST_DNS_RG:-rg-test-runner}"
export TEST_DNS_SUB="${TEST_DNS_SUB:-$TEST_MHCORE_SUB}"
export TEST_TR_RG="${TEST_TR_RG:-rg-test-runner}"
export TEST_TR_VNET="${TEST_TR_VNET:-vnet-test-runner}"
export TEST_ADB_NAME="${TEST_ADB_NAME:-adbtest00}"

echo "============================================"
echo "Workshop Challenge Tests (Standalone E2E)"
echo "============================================"
echo "MHCORE Sub: $TEST_MHCORE_SUB"
echo "MH0 Sub:    $TEST_MH0_SUB"
echo "MHODAA Sub: $TEST_MHODAA_SUB"
echo "ADB Name:   $TEST_ADB_NAME"
echo "DNS RG:     $TEST_DNS_RG"
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
