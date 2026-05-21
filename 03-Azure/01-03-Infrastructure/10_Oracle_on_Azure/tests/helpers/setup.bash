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
export TEST_USER_INDEX="${TEST_USER_INDEX:-00}"
export TEST_RG="rg-user${TEST_USER_INDEX}"
export TEST_VM="vm-user${TEST_USER_INDEX}"
export TEST_VNET="vnet-user${TEST_USER_INDEX}"
export TEST_DNS_ZONE="adb.eu-paris-1.oraclecloud.com"
