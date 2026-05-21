#!/usr/bin/env bats
# Challenge 2: ADB instance is deployed and reachable

setup() {
  load 'helpers/setup'
}

@test "User VM exists and is running" {
  run az vm show --name "$TEST_VM" \
    --resource-group "$TEST_RG" \
    --subscription "$TEST_MH0_SUB" \
    -o tsv --query "provisioningState"
  assert_success
  assert_output "Succeeded"
}

@test "User VNet has expected address space" {
  run az network vnet show --name "$TEST_VNET" \
    --resource-group "$TEST_RG" \
    --subscription "$TEST_MH0_SUB" \
    -o tsv --query "addressSpace.addressPrefixes[0]"
  assert_success
  assert_output --regexp '^10\.0\.[0-9]+\.0/24$'
}
