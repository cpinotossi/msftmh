#!/usr/bin/env bash
load '/opt/bats-support/load'
load '/opt/bats-assert/load'

# Every topology/DNS value comes from canonical ARM deployments or actual ARM/OCI reads.

db_property() {
  az rest --method GET \
    --url "https://management.azure.com${TEST_DB_ID}?api-version=2025-09-01" \
    --query "$1" --output tsv
}
