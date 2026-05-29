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

@test "Test-runner VNet peering to ODAA is connected" {
  run az network vnet peering list \
    --vnet-name "$TEST_TR_VNET" \
    --resource-group "$TEST_TR_RG" \
    --subscription "$TEST_MHCORE_SUB" \
    -o tsv --query "[?contains(name,'odaa')].peeringState"
  assert_success
  refute_output ''
  while IFS= read -r line; do
    [[ "$line" == "Connected" ]]
  done <<< "$output"
}
