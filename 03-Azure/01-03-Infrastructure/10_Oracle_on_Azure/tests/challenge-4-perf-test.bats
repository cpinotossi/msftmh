#!/usr/bin/env bats
# Challenge 4: Performance tools are available and ADB is reachable
# Test-runner uses the same Gallery image as user VMs → has all Oracle tools.

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
  run file -L "$(which adbping)"
  assert_success
  assert_output --partial "ELF"
}

@test "Oracle Instant Client sqlplus is available" {
  run sqlplus -V
  assert_success
  assert_output --partial "SQL*Plus"
}

@test "ADB DNS resolves from test-runner network" {
  local host
  host=$(az network private-dns record-set a list \
    --zone-name "$TEST_DNS_ZONE" \
    --resource-group "$TEST_DNS_RG" \
    --subscription "$TEST_DNS_SUB" \
    -o tsv --query "[0].fqdn")
  run dig +short "$host"
  assert_success
  assert_output --regexp '^[0-9]+\.'
}

@test "connping reaches ADB endpoint" {
  local ip
  ip=$(az network private-dns record-set a list \
    --zone-name "$TEST_DNS_ZONE" \
    --resource-group "$TEST_DNS_RG" \
    --subscription "$TEST_DNS_SUB" \
    -o tsv --query "[0].aRecords[0].ipv4Address")
  run connping "$ip" 1522
  assert_success
}

@test "adbping reaches ADB endpoint" {
  local ip
  ip=$(az network private-dns record-set a list \
    --zone-name "$TEST_DNS_ZONE" \
    --resource-group "$TEST_DNS_RG" \
    --subscription "$TEST_DNS_SUB" \
    -o tsv --query "[0].aRecords[0].ipv4Address")
  run adbping "$ip" 1522
  assert_success
}
