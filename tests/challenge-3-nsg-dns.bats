#!/usr/bin/env bats
# Challenge 3: NSG rules and DNS configuration (created by setup job)

setup() {
  load 'helpers/setup'
}

@test "Private DNS zone exists for ADB" {
  run az network private-dns zone show \
    --name "$TEST_DNS_ZONE" \
    --resource-group "$TEST_DNS_RG" \
    --subscription "$TEST_DNS_SUB" \
    -o tsv --query "name"
  assert_success
  assert_output "$TEST_DNS_ZONE"
}

@test "DNS zone is linked to test-runner VNet" {
  local links
  links=$(az network private-dns link vnet list \
    --zone-name "$TEST_DNS_ZONE" \
    --resource-group "$TEST_DNS_RG" \
    --subscription "$TEST_DNS_SUB" \
    -o tsv --query "length(@)")
  [ "$links" -ge 1 ]
}

@test "A-record exists in DNS zone" {
  local records
  records=$(az network private-dns record-set a list \
    --zone-name "$TEST_DNS_ZONE" \
    --resource-group "$TEST_DNS_RG" \
    --subscription "$TEST_DNS_SUB" \
    -o tsv --query "length(@)")
  [ "$records" -ge 1 ]
}

@test "A-record resolves to a valid IP" {
  local ip
  ip=$(az network private-dns record-set a list \
    --zone-name "$TEST_DNS_ZONE" \
    --resource-group "$TEST_DNS_RG" \
    --subscription "$TEST_DNS_SUB" \
    -o tsv --query "[0].aRecords[0].ipv4Address")
  [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "OCI NSG has ingress rule allowing test-runner subnet" {
  # ODAA may not use OCI-side NSGs (Azure VNet provides isolation)
  if [[ -z "$TEST_NSG_OCID" ]]; then
    skip "No OCI NSG — ODAA uses Azure VNet for network isolation"
  fi
  local rules
  rules=$(oci network nsg rules list \
    --nsg-id "$TEST_NSG_OCID" \
    --direction INGRESS \
    --query "data[?source=='10.200.0.0/24']" 2>/dev/null || echo "[]")
  [[ "$rules" != "[]" ]]
}
