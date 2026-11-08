#!/usr/bin/env bats
setup() { load 'helpers/setup'; }

@test "Base DB system provisioning succeeded" {
  run db_property properties.provisioningState
  assert_success
  assert_output Succeeded
}

@test "Base DB system lifecycle is Available" {
  run db_property properties.lifecycleState
  assert_success
  assert_output Available
}

@test "Base DB uses a single Enterprise Edition node with included licensing" {
  run db_property "join('|', [to_string(properties.nodeCount), properties.databaseEdition, properties.licenseModel])"
  assert_success
  assert_output '1|EnterpriseEdition|LicenseIncluded'
}

@test "Base DB shape and database version match the explicit regional selection" {
  run db_property "join('|', [properties.shape, properties.dbVersion])"
  assert_success
  assert_output "$TEST_DB_SHAPE|$TEST_DB_VERSION"
}

@test "Base DB uses the dedicated owned network anchor" {
  run db_property properties.networkAnchorId
  assert_success
  assert_output "$TEST_NETWORK_ANCHOR_ID"
}

@test "Base DB compute model count and initial storage match the explicit inputs" {
  run db_property "join('|', [properties.computeModel, to_string(properties.computeCount), to_string(properties.initialDataStorageSizeInGb)])"
  assert_success
  assert_output "$TEST_DB_COMPUTE_MODEL|$TEST_DB_COMPUTE|$TEST_DB_STORAGE"
}
