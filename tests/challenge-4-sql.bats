#!/usr/bin/env bats
setup() { load 'helpers/setup'; }

@test "SQL authenticates to the actual PDB and SELECT returns the expected value" {
  run python3 /opt/tests/sql_probe.py
  assert_success
  assert_output SQL_PDB_OK
}
