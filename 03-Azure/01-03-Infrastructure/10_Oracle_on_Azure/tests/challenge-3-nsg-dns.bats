#!/usr/bin/env bats
# Challenge 3: NSG rules and DNS configuration

setup() {
  load 'helpers/setup'
}

@test "VNet peering to ODAA VNet is connected" {
  run az network vnet peering list \
    --vnet-name "$TEST_VNET" \
    --resource-group "$TEST_RG" \
    --subscription "$TEST_MH0_SUB" \
    -o tsv --query "[?contains(name,'odaa')].peeringState"
  assert_success
  # May return multiple peerings (ODAA + BaseDB), all must be Connected
  refute_output ''
  while IFS= read -r line; do
    [[ "$line" == "Connected" ]]
  done <<< "$output"
}

@test "Private DNS zone exists for ADB" {
  run az network private-dns zone show \
    --name "$TEST_DNS_ZONE" \
    --resource-group "$TEST_RG" \
    --subscription "$TEST_MH0_SUB" \
    -o tsv --query "name"
  assert_success
  assert_output "$TEST_DNS_ZONE"
}

@test "DNS zone is linked to user VNet" {
  local links
  links=$(az network private-dns link vnet list \
    --zone-name "$TEST_DNS_ZONE" \
    --resource-group "$TEST_RG" \
    --subscription "$TEST_MH0_SUB" \
    -o tsv --query "length(@)")
  [ "$links" -ge 1 ]
}

@test "A-record exists in DNS zone (user challenge)" {
  local records
  records=$(az network private-dns record-set a list \
    --zone-name "$TEST_DNS_ZONE" \
    --resource-group "$TEST_RG" \
    --subscription "$TEST_MH0_SUB" \
    -o tsv --query "length(@)" 2>/dev/null || echo "0")
  if [ "$records" -eq 0 ]; then
    skip "No A-records yet (user has not completed Challenge 3)"
  fi
  [ "$records" -ge 1 ]
}
