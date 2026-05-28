#!/usr/bin/env bats
# Challenge 2: ADB instance was created and is available

setup() {
  load 'helpers/setup'
}

@test "ADB resource exists in ODAA resource group" {
  run az oracle-database autonomous-database show \
    --name "$TEST_ADB_NAME" \
    --resource-group "$TEST_ODAA_RG" \
    --subscription "$TEST_MHODAA_SUB" \
    -o tsv --query "name"
  assert_success
  assert_output "$TEST_ADB_NAME"
}

@test "ADB lifecycle state is Available" {
  run az oracle-database autonomous-database show \
    --name "$TEST_ADB_NAME" \
    --resource-group "$TEST_ODAA_RG" \
    --subscription "$TEST_MHODAA_SUB" \
    -o tsv --query "properties.lifecycleState"
  assert_success
  assert_output "Available"
}

@test "ADB compute model is ECPU with count 2" {
  local model count
  model=$(az oracle-database autonomous-database show \
    --name "$TEST_ADB_NAME" \
    --resource-group "$TEST_ODAA_RG" \
    --subscription "$TEST_MHODAA_SUB" \
    -o tsv --query "properties.computeModel")
  count=$(az oracle-database autonomous-database show \
    --name "$TEST_ADB_NAME" \
    --resource-group "$TEST_ODAA_RG" \
    --subscription "$TEST_MHODAA_SUB" \
    -o tsv --query "properties.computeCount")
  [[ "$model" == "ECPU" ]]
  [[ "$count" == "2" ]]
}

@test "ADB workload type is OLTP (Transaction Processing)" {
  run az oracle-database autonomous-database show \
    --name "$TEST_ADB_NAME" \
    --resource-group "$TEST_ODAA_RG" \
    --subscription "$TEST_MHODAA_SUB" \
    -o tsv --query "properties.dbWorkload"
  assert_success
  assert_output "OLTP"
}

@test "ADB storage is 20 GB without auto-scaling" {
  local storage autoscale
  storage=$(az oracle-database autonomous-database show \
    --name "$TEST_ADB_NAME" \
    --resource-group "$TEST_ODAA_RG" \
    --subscription "$TEST_MHODAA_SUB" \
    -o tsv --query "properties.dataStorageSizeInGbs")
  autoscale=$(az oracle-database autonomous-database show \
    --name "$TEST_ADB_NAME" \
    --resource-group "$TEST_ODAA_RG" \
    --subscription "$TEST_MHODAA_SUB" \
    -o tsv --query "properties.isAutoScalingForStorageEnabled")
  [[ "$storage" == "20" ]]
  [[ "$autoscale" == "false" || "$autoscale" == "False" ]]
}
