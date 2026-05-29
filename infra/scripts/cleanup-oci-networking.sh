#!/usr/bin/env bash
# cleanup-oci-networking.sh
#
# Delete orphaned OCI networking resources (NSGs, Subnets, Gateways, VCNs)
# left behind after Oracle Database@Azure resources are removed.
#
# Auth: OCI CLI env vars (OCI_CLI_USER, OCI_CLI_TENANCY, OCI_CLI_FINGERPRINT,
#        OCI_CLI_KEY_CONTENT, OCI_CLI_REGION) — no config file needed.
#
# Usage:
#   DRY_RUN=true  ./cleanup-oci-networking.sh   # preview only
#   DRY_RUN=false ./cleanup-oci-networking.sh   # actually delete
#
set -euo pipefail

COMPARTMENT_ID="${OCI_COMPARTMENT_ID:-ocid1.compartment.oc1..aaaaaaaayehuog6myqxudqejx3ddy6bzkr2f3dnjuuygs424taimn4av4wbq}"
DRY_RUN="${DRY_RUN:-true}"
ERRORS=0

log()  { echo "  $*"; }
ok()   { echo "    ✅ $*"; }
fail() { echo "    ❌ $*"; ERRORS=$((ERRORS + 1)); }
skip() { echo "    [DRY RUN] Would delete: $*"; }

# ---------------------------------------------------------------------------
# Verify OCI CLI is available
# ---------------------------------------------------------------------------
if ! command -v oci &>/dev/null; then
  echo "ERROR: oci CLI not found. Install with: pip install oci-cli"
  exit 1
fi

echo "============================================================"
echo "OCI Networking Cleanup"
echo "============================================================"
echo "  Compartment: ${COMPARTMENT_ID:0:50}..."
echo "  Region:      ${OCI_CLI_REGION:-not set}"
echo "  Dry Run:     ${DRY_RUN}"
echo "============================================================"
echo ""

# ---------------------------------------------------------------------------
# Helper: delete a resource with retry
# ---------------------------------------------------------------------------
delete_resource() {
  local resource_type="$1"
  local resource_id="$2"
  local display_name="$3"
  local delete_cmd="$4"

  if [[ "${DRY_RUN}" == "true" ]]; then
    skip "${resource_type}: ${display_name}"
    return 0
  fi

  log "Deleting ${resource_type}: ${display_name}"
  if eval "${delete_cmd}" 2>/dev/null; then
    ok "Deleted ${display_name}"
  else
    fail "Failed to delete ${resource_type}: ${display_name} (${resource_id})"
  fi
}

# ---------------------------------------------------------------------------
# Step 1: List and delete NSGs
# ---------------------------------------------------------------------------
echo "=== Step 1: Network Security Groups ==="
echo ""

NSG_JSON=$(oci network nsg list \
  --compartment-id "${COMPARTMENT_ID}" \
  --all \
  --query 'data[?\"lifecycle-state\"==`AVAILABLE`].[id,\"display-name\"]' \
  --output json 2>/dev/null || echo "[]")

NSG_COUNT=$(echo "${NSG_JSON}" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
log "Found ${NSG_COUNT} NSG(s)"

echo "${NSG_JSON}" | python3 -c "
import sys, json
for item in json.load(sys.stdin):
    print(f'{item[0]}|{item[1]}')
" | while IFS='|' read -r nsg_id nsg_name; do
  [[ -z "${nsg_id}" ]] && continue
  delete_resource "NSG" "${nsg_id}" "${nsg_name}" \
    "oci network nsg delete --nsg-id '${nsg_id}' --force --wait-for-state TERMINATED 2>/dev/null"
done

echo ""

# ---------------------------------------------------------------------------
# Step 2: List VCNs and delete their dependencies, then the VCNs
# ---------------------------------------------------------------------------
echo "=== Step 2: VCNs and Dependencies ==="
echo ""

VCN_JSON=$(oci network vcn list \
  --compartment-id "${COMPARTMENT_ID}" \
  --all \
  --query 'data[?\"lifecycle-state\"==`AVAILABLE`].[id,\"display-name\",\"default-route-table-id\",\"default-security-list-id\"]' \
  --output json 2>/dev/null || echo "[]")

VCN_COUNT=$(echo "${VCN_JSON}" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
log "Found ${VCN_COUNT} VCN(s)"
echo ""

echo "${VCN_JSON}" | python3 -c "
import sys, json
for item in json.load(sys.stdin):
    print(f'{item[0]}|{item[1]}|{item[2]}|{item[3]}')
" | while IFS='|' read -r vcn_id vcn_name default_rt default_sl; do
  [[ -z "${vcn_id}" ]] && continue
  echo "--- VCN: ${vcn_name} ---"

  # 2a: Subnets
  SUBNET_JSON=$(oci network subnet list \
    --compartment-id "${COMPARTMENT_ID}" \
    --vcn-id "${vcn_id}" \
    --all \
    --query 'data[].[id,\"display-name\"]' \
    --output json 2>/dev/null || echo "[]")

  echo "${SUBNET_JSON}" | python3 -c "
import sys, json
for item in json.load(sys.stdin):
    print(f'{item[0]}|{item[1]}')
" | while IFS='|' read -r sub_id sub_name; do
    [[ -z "${sub_id}" ]] && continue
    delete_resource "Subnet" "${sub_id}" "${sub_name}" \
      "oci network subnet delete --subnet-id '${sub_id}' --force --wait-for-state TERMINATED 2>/dev/null"
  done

  # 2b: Internet Gateways
  IGW_JSON=$(oci network internet-gateway list \
    --compartment-id "${COMPARTMENT_ID}" \
    --vcn-id "${vcn_id}" \
    --all \
    --query 'data[].[id,\"display-name\"]' \
    --output json 2>/dev/null || echo "[]")

  echo "${IGW_JSON}" | python3 -c "
import sys, json
for item in json.load(sys.stdin):
    print(f'{item[0]}|{item[1]}')
" | while IFS='|' read -r igw_id igw_name; do
    [[ -z "${igw_id}" ]] && continue
    delete_resource "Internet GW" "${igw_id}" "${igw_name}" \
      "oci network internet-gateway delete --ig-id '${igw_id}' --force --wait-for-state TERMINATED 2>/dev/null"
  done

  # 2c: NAT Gateways
  NAT_JSON=$(oci network nat-gateway list \
    --compartment-id "${COMPARTMENT_ID}" \
    --vcn-id "${vcn_id}" \
    --all \
    --query 'data[].[id,\"display-name\"]' \
    --output json 2>/dev/null || echo "[]")

  echo "${NAT_JSON}" | python3 -c "
import sys, json
for item in json.load(sys.stdin):
    print(f'{item[0]}|{item[1]}')
" | while IFS='|' read -r nat_id nat_name; do
    [[ -z "${nat_id}" ]] && continue
    delete_resource "NAT GW" "${nat_id}" "${nat_name}" \
      "oci network nat-gateway delete --nat-gateway-id '${nat_id}' --force --wait-for-state TERMINATED 2>/dev/null"
  done

  # 2d: Service Gateways
  SGW_JSON=$(oci network service-gateway list \
    --compartment-id "${COMPARTMENT_ID}" \
    --vcn-id "${vcn_id}" \
    --all \
    --query 'data[].[id,\"display-name\"]' \
    --output json 2>/dev/null || echo "[]")

  echo "${SGW_JSON}" | python3 -c "
import sys, json
for item in json.load(sys.stdin):
    print(f'{item[0]}|{item[1]}')
" | while IFS='|' read -r sgw_id sgw_name; do
    [[ -z "${sgw_id}" ]] && continue
    delete_resource "Service GW" "${sgw_id}" "${sgw_name}" \
      "oci network service-gateway delete --service-gateway-id '${sgw_id}' --force --wait-for-state TERMINATED 2>/dev/null"
  done

  # 2e: Non-default Route Tables
  RT_JSON=$(oci network route-table list \
    --compartment-id "${COMPARTMENT_ID}" \
    --vcn-id "${vcn_id}" \
    --all \
    --query 'data[].[id,\"display-name\"]' \
    --output json 2>/dev/null || echo "[]")

  echo "${RT_JSON}" | python3 -c "
import sys, json
for item in json.load(sys.stdin):
    print(f'{item[0]}|{item[1]}')
" | while IFS='|' read -r rt_id rt_name; do
    [[ -z "${rt_id}" ]] && continue
    # Skip the default route table — it gets deleted with the VCN
    if [[ "${rt_id}" == "${default_rt}" ]]; then
      log "  Skipping default route table: ${rt_name}"
      continue
    fi
    delete_resource "Route Table" "${rt_id}" "${rt_name}" \
      "oci network route-table delete --rt-id '${rt_id}' --force --wait-for-state TERMINATED 2>/dev/null"
  done

  # 2f: Non-default Security Lists
  SL_JSON=$(oci network security-list list \
    --compartment-id "${COMPARTMENT_ID}" \
    --vcn-id "${vcn_id}" \
    --all \
    --query 'data[].[id,\"display-name\"]' \
    --output json 2>/dev/null || echo "[]")

  echo "${SL_JSON}" | python3 -c "
import sys, json
for item in json.load(sys.stdin):
    print(f'{item[0]}|{item[1]}')
" | while IFS='|' read -r sl_id sl_name; do
    [[ -z "${sl_id}" ]] && continue
    if [[ "${sl_id}" == "${default_sl}" ]]; then
      log "  Skipping default security list: ${sl_name}"
      continue
    fi
    delete_resource "Security List" "${sl_id}" "${sl_name}" \
      "oci network security-list delete --security-list-id '${sl_id}' --force --wait-for-state TERMINATED 2>/dev/null"
  done

  # 2g: Delete VCN
  echo ""
  delete_resource "VCN" "${vcn_id}" "${vcn_name}" \
    "oci network vcn delete --vcn-id '${vcn_id}' --force --wait-for-state TERMINATED 2>/dev/null"
  echo ""
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "============================================================"
if [[ "${DRY_RUN}" == "true" ]]; then
  echo "🔒 DRY RUN complete — no resources were deleted."
  echo "   Set DRY_RUN=false to delete."
elif [[ "${ERRORS}" -gt 0 ]]; then
  echo "⚠️  Cleanup finished with ${ERRORS} error(s)."
else
  echo "✅ OCI networking cleanup complete."
fi
echo "============================================================"

exit "${ERRORS}"
