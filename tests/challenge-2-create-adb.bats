#!/usr/bin/env bats
# Challenge 2: ADB instance was created and is available
# Uses az rest instead of az oracle-database CLI (extension has data_base_type bug)

setup() {
  load 'helpers/setup'
}

# Helper: query ADB via REST API
_adb_prop() {
  az rest --method GET \
    --url "https://management.azure.com/subscriptions/${TEST_MHODAA_SUB}/resourceGroups/${TEST_ODAA_RG}/providers/Oracle.Database/autonomousDatabases/${TEST_ADB_NAME}?api-version=2025-03-01" \
    --query "$1" -o tsv 2>/dev/null
}

@test "ADB resource exists in ODAA resource group" {
  run _adb_prop "name"
  assert_success
  assert_output "$TEST_ADB_NAME"
}

@test "ADB lifecycle state is Available" {
  run _adb_prop "properties.lifecycleState"
  assert_success
  assert_output "Available"
}

@test "ADB compute model is ECPU with count 2" {
  local model count
  model=$(_adb_prop "properties.computeModel")
  count=$(_adb_prop "properties.computeCount")
  [[ "$model" == "ECPU" ]]
  [[ "$count" == "2" ]]
}

@test "ADB workload type is OLTP (Transaction Processing)" {
  run _adb_prop "properties.dbWorkload"
  assert_success
  assert_output "OLTP"
}

@test "ADB storage is 20 GB without auto-scaling" {
  local storage autoscale
  storage=$(_adb_prop "properties.dataStorageSizeInGbs")
  autoscale=$(_adb_prop "properties.isAutoScalingForStorageEnabled")
  [[ "$storage" == "20" ]]
  [[ "$autoscale" == "false" || "$autoscale" == "False" ]]
}
