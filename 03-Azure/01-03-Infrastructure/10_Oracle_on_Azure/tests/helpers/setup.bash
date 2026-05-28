#!/usr/bin/env bash
# Common setup for all BATS test files

# Load BATS helpers
load '/opt/bats-support/load'
load '/opt/bats-assert/load'

# Login with managed identity (once per file)
setup_file() {
  az login --identity --allow-no-subscriptions >/dev/null 2>&1
}

# Common variables (set by run-tests.sh wrapper)
export TEST_MH0_SUB="${TEST_MH0_SUB:-}"
export TEST_MHODAA_SUB="${TEST_MHODAA_SUB:-}"
export TEST_MHCORE_SUB="${TEST_MHCORE_SUB:-}"
export TEST_DNS_ZONE="adb.eu-paris-1.oraclecloud.com"
export TEST_DNS_RG="${TEST_DNS_RG:-rg-test-runner}"
export TEST_DNS_SUB="${TEST_DNS_SUB:-$TEST_MHCORE_SUB}"
export TEST_ODAA_RG="rg-odaa-shared"
export TEST_ODAA_VNET="vnet-odaa-shared"
export TEST_TR_VNET="${TEST_TR_VNET:-vnet-test-runner}"
export TEST_TR_RG="${TEST_TR_RG:-rg-test-runner}"
export TEST_ADB_NAME="${TEST_ADB_NAME:-adbtest00}"
