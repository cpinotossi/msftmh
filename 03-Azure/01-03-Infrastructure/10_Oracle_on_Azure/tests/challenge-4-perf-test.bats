#!/usr/bin/env bats
# Challenge 4: Performance tools are available and ADB is reachable
# NOTE: connping/adbping connectivity tests require an active ADB
# instance with credentials. These tests validate tool availability
# and basic network reachability.

setup() {
  load 'helpers/setup'
}

@test "connping binary is available" {
  run which connping
  assert_success
}

@test "adbping binary is available" {
  run which adbping
  assert_success
}

@test "adbping is a real binary (not placeholder)" {
  run file "$(which adbping)"
  assert_success
  assert_output --partial "ELF"
}

@test "Oracle Instant Client sqlplus is available" {
  run sqlplus -V
  assert_success
  assert_output --partial "SQL*Plus"
}

@test "ADB DNS resolves from test-runner network" {
  # Skip if no A records exist yet (ADB not provisioned)
  local records
  records=$(az network private-dns record-set a list \
    --zone-name "$TEST_DNS_ZONE" \
    --resource-group "$TEST_RG" \
    --subscription "$TEST_MH0_SUB" \
    -o tsv --query "length(@)" 2>/dev/null || echo "0")
  if [ "$records" -eq 0 ]; then
    skip "No DNS A records found (ADB not yet provisioned)"
  fi
  local host
  host=$(az network private-dns record-set a list \
    --zone-name "$TEST_DNS_ZONE" \
    --resource-group "$TEST_RG" \
    --subscription "$TEST_MH0_SUB" \
    -o tsv --query "[0].fqdn")
  run dig +short "$host"
  assert_success
  assert_output --regexp '^[0-9]+\.'
}
