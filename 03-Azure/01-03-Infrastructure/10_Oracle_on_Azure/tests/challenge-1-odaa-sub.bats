#!/usr/bin/env bats
# Challenge 1: ODAA Subscription exists and is accessible

setup() {
  load 'helpers/setup'
}

@test "ODAA shared resource group exists" {
  run az group show --name rg-odaa-shared \
    --subscription "$TEST_MHODAA_SUB" -o tsv --query "name"
  assert_success
  assert_output "rg-odaa-shared"
}

@test "ODAA shared VNet exists" {
  run az network vnet show --name vnet-odaa-shared \
    --resource-group rg-odaa-shared \
    --subscription "$TEST_MHODAA_SUB" -o tsv --query "name"
  assert_success
  assert_output "vnet-odaa-shared"
}
