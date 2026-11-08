#!/usr/bin/env bats
# Challenge 1: ODAA Subscription and shared infrastructure exist

setup() {
  load 'helpers/setup'
}

@test "ODAA shared resource group exists" {
  run az group show --name "$TEST_ODAA_RG" \
    --subscription "$TEST_MHODAA_SUB" -o tsv --query "name"
  assert_success
  assert_output "$TEST_ODAA_RG"
}

@test "ODAA shared VNet exists" {
  run az network vnet show --name "$TEST_ODAA_VNET" \
    --resource-group "$TEST_ODAA_RG" \
    --subscription "$TEST_MHODAA_SUB" -o tsv --query "name"
  assert_success
  assert_output "$TEST_ODAA_VNET"
}

@test "Test-runner uses hub-only peering exact Oracle UDR and firewall DNS proxy" {
  run python3 /opt/tests/network_probe.py --topology
  assert_success
  assert_output 'HUB_TOPOLOGY_OK'
}
