#!/usr/bin/env bats
setup() { load 'helpers/setup'; }

@test "Base DB native DNS works over UDP TCP through the firewall only" {
  run python3 /opt/tests/network_probe.py --dns
  assert_success
  assert_output 'FIREWALL_DNS_OK'
}

@test "Base DB workshop DNS resolves on the isolated VM" {
  run python3 /opt/tests/sql_probe.py --resolve
  assert_success
  assert_output 'DNS_OK'
}

@test "Base DB exposes the discovered TCP listener rather than an ADB TLS endpoint" {
  run db_property properties.listenerPort
  assert_success
  assert_output "$TEST_DB_PORT"
  [[ "$TEST_DB_PORT" != 1522 ]]
}
