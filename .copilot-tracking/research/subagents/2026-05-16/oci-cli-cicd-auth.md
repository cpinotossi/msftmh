# Research: OCI CLI Authentication in GitHub Actions CI/CD Pipeline

## Research Questions

1. How to authenticate OCI CLI non-interactively in a GitHub Actions pipeline?
2. What GitHub secrets are needed?
3. Can `oci-cli` be installed inline via pip?
4. What IAM permissions are needed to delete VCNs and NSGs?
5. What is the correct deletion order for VCN resources?
6. What are the exact OCI CLI commands for listing/deleting VCNs and NSGs?

---

## Findings

### 1. Recommended Auth Approach: API Key via Environment Variables

The official Oracle GitHub Action (`oracle-actions/run-oci-cli-command@v1.3.2`) uses **OCI CLI environment variables** for authentication. This is the recommended non-interactive approach.

The OCI CLI accepts authentication credentials via environment variables (no config file needed):

| Environment Variable | Description |
|---|---|
| `OCI_CLI_USER` | User OCID (the service user's OCID) |
| `OCI_CLI_TENANCY` | Tenancy OCID |
| `OCI_CLI_FINGERPRINT` | API key fingerprint (e.g. `12:34:56:...`) |
| `OCI_CLI_KEY_CONTENT` | PEM private key content (full key text) |
| `OCI_CLI_REGION` | Region identifier (e.g. `eu-paris-1`) |

**Why this approach over config file generation:**
- No file I/O needed — environment variables work directly
- No risk of leaving key files on disk
- Oracle's official GitHub Action uses exactly this pattern
- The self-hosted runner can set these from GitHub secrets at workflow level

**Alternative: Config file at runtime** — write `~/.oci/config` and `~/.oci/key.pem` from secrets. Works but adds unnecessary complexity when env vars suffice.

### 2. GitHub Secrets Needed

| Secret Name | Value |
|---|---|
| `OCI_CLI_USER` | `ocid1.user.oc1..aaaa...` (service user OCID) |
| `OCI_CLI_TENANCY` | `ocid1.tenancy.oc1..aaaaaaaarkr3tvxxmzwueaz3dazimmlsoqk2nc6j77vg33jinbnaupdnokxa` |
| `OCI_CLI_FINGERPRINT` | API key fingerprint |
| `OCI_CLI_KEY_CONTENT` | Full PEM private key content |
| `OCI_CLI_REGION` | `eu-paris-1` |
| `OCI_COMPARTMENT_ID` | Target compartment OCID (optional, convenience) |

**Setup steps in OCI Console:**
1. Create a service user (or use existing) in OCI IAM
2. Generate API key pair (Console or `openssl genrsa -out key.pem 2048`)
3. Upload public key to user's API Keys section
4. Copy fingerprint, user OCID, tenancy OCID
5. Store private key content and all identifiers as GitHub secrets

### 3. OCI CLI Installation in Pipeline

**Yes — `pip install oci-cli` works inline:**

```bash
pip install oci-cli
oci --version
```

**Alternatively, the official GitHub Action handles this automatically:**

```yaml
- uses: oracle-actions/run-oci-cli-command@v1.3.2
  with:
    command: 'network vcn list --compartment-id ${{ secrets.OCI_COMPARTMENT_ID }}'
```

For a self-hosted Azure Container Apps runner, inline pip install is simplest since you control the environment. The `oci-cli` package installs quickly and includes all networking commands.

### 4. IAM Permissions Needed

The OCI IAM policy required to delete VCNs, NSGs, subnets, gateways, etc.:

```
Allow group <GroupName> to manage virtual-network-family in tenancy
```

Or scoped to a compartment:

```
Allow group <GroupName> to manage virtual-network-family in compartment <CompartmentName>
```

The `virtual-network-family` aggregate resource covers:
- VCNs
- Subnets
- Network Security Groups (NSGs)
- Security Lists
- Route Tables
- Internet Gateways
- NAT Gateways
- Service Gateways
- Local Peering Gateways
- DRG Attachments
- DHCP Options

### 5. VCN Deletion Order (Dependencies)

**Critical constraint from OCI docs:** "The VCN must be completely empty and have no attached gateways."

**NSG constraint:** "The group must not contain any VNICs."

**Required deletion order (inside-out):**

1. **Terminate compute instances** (if any VNICs are in NSGs)
2. **Delete Network Security Groups** (must have no VNICs attached)
3. **Delete Subnets** (must be empty — no instances, load balancers, etc.)
4. **Delete Internet Gateways**
5. **Delete NAT Gateways**
6. **Delete Service Gateways**
7. **Delete Local Peering Gateways**
8. **Delete non-default Route Tables** (default RT deleted with VCN)
9. **Delete non-default Security Lists** (default SL deleted with VCN)
10. **Delete non-default DHCP Options**
11. **Delete DRG Attachments** (if any)
12. **Delete VCN**

### 6. OCI CLI Commands

#### List VCNs in a compartment

```bash
oci network vcn list --compartment-id "$COMPARTMENT_ID" --all --query 'data[*].{id:id, name:"display-name", state:"lifecycle-state"}' --output table
```

#### List NSGs in a compartment

```bash
oci network nsg list --compartment-id "$COMPARTMENT_ID" --all --query 'data[*].{id:id, name:"display-name", vcn:"vcn-id", state:"lifecycle-state"}' --output table
```

#### List subnets in a compartment

```bash
oci network subnet list --compartment-id "$COMPARTMENT_ID" --all
```

#### List gateways

```bash
oci network internet-gateway list --compartment-id "$COMPARTMENT_ID" --vcn-id "$VCN_ID" --all
oci network nat-gateway list --compartment-id "$COMPARTMENT_ID" --vcn-id "$VCN_ID" --all  
oci network service-gateway list --compartment-id "$COMPARTMENT_ID" --vcn-id "$VCN_ID" --all
oci network local-peering-gateway list --compartment-id "$COMPARTMENT_ID" --vcn-id "$VCN_ID" --all
```

#### Delete NSG

```bash
oci network nsg delete --nsg-id "$NSG_ID" --force --wait-for-state TERMINATED
```

#### Delete subnet

```bash
oci network subnet delete --subnet-id "$SUBNET_ID" --force --wait-for-state TERMINATED
```

#### Delete gateways

```bash
oci network internet-gateway delete --ig-id "$IG_ID" --force --wait-for-state TERMINATED
oci network nat-gateway delete --nat-gateway-id "$NAT_ID" --force --wait-for-state TERMINATED
oci network service-gateway delete --service-gateway-id "$SGW_ID" --force
oci network local-peering-gateway delete --local-peering-gateway-id "$LPG_ID" --force
```

#### Delete route tables (non-default only)

```bash
oci network route-table delete --rt-id "$RT_ID" --force --wait-for-state TERMINATED
```

#### Delete security lists (non-default only)

```bash
oci network security-list delete --security-list-id "$SL_ID" --force --wait-for-state TERMINATED
```

#### Delete VCN

```bash
oci network vcn delete --vcn-id "$VCN_ID" --force --wait-for-state TERMINATED
```

---

## Shell Script Snippet for Pipeline Step

```bash
#!/usr/bin/env bash
set -euo pipefail

# --- Configuration (from GitHub secrets / env vars) ---
# OCI_CLI_USER, OCI_CLI_TENANCY, OCI_CLI_FINGERPRINT, OCI_CLI_KEY_CONTENT, OCI_CLI_REGION
# are already set as environment variables by the workflow

COMPARTMENT_ID="${OCI_COMPARTMENT_ID}"

echo "=== OCI VCN/NSG Cleanup Script ==="
echo "Region: ${OCI_CLI_REGION}"
echo "Compartment: ${COMPARTMENT_ID}"

# --- Install OCI CLI if not present ---
if ! command -v oci &> /dev/null; then
  echo "Installing OCI CLI..."
  pip install oci-cli --quiet
fi

# --- Helper: delete all resources of a type within a VCN ---
delete_vcn_resources() {
  local vcn_id="$1"
  echo "  Cleaning VCN: ${vcn_id}"

  # 1. Delete NSGs
  echo "  Deleting NSGs..."
  NSG_IDS=$(oci network nsg list --compartment-id "$COMPARTMENT_ID" --vcn-id "$vcn_id" --all --query 'data[*].id' --raw-output 2>/dev/null | tr -d '[]" ' | tr ',' '\n')
  for nsg_id in $NSG_IDS; do
    [ -z "$nsg_id" ] && continue
    echo "    Deleting NSG: $nsg_id"
    oci network nsg delete --nsg-id "$nsg_id" --force --wait-for-state TERMINATED --max-wait-seconds 120 || true
  done

  # 2. Delete Subnets
  echo "  Deleting Subnets..."
  SUBNET_IDS=$(oci network subnet list --compartment-id "$COMPARTMENT_ID" --vcn-id "$vcn_id" --all --query 'data[*].id' --raw-output 2>/dev/null | tr -d '[]" ' | tr ',' '\n')
  for subnet_id in $SUBNET_IDS; do
    [ -z "$subnet_id" ] && continue
    echo "    Deleting Subnet: $subnet_id"
    oci network subnet delete --subnet-id "$subnet_id" --force --wait-for-state TERMINATED --max-wait-seconds 300 || true
  done

  # 3. Delete Internet Gateways
  echo "  Deleting Internet Gateways..."
  IG_IDS=$(oci network internet-gateway list --compartment-id "$COMPARTMENT_ID" --vcn-id "$vcn_id" --all --query 'data[*].id' --raw-output 2>/dev/null | tr -d '[]" ' | tr ',' '\n')
  for ig_id in $IG_IDS; do
    [ -z "$ig_id" ] && continue
    echo "    Deleting IG: $ig_id"
    oci network internet-gateway delete --ig-id "$ig_id" --force --wait-for-state TERMINATED --max-wait-seconds 120 || true
  done

  # 4. Delete NAT Gateways
  echo "  Deleting NAT Gateways..."
  NAT_IDS=$(oci network nat-gateway list --compartment-id "$COMPARTMENT_ID" --vcn-id "$vcn_id" --all --query 'data[*].id' --raw-output 2>/dev/null | tr -d '[]" ' | tr ',' '\n')
  for nat_id in $NAT_IDS; do
    [ -z "$nat_id" ] && continue
    echo "    Deleting NAT GW: $nat_id"
    oci network nat-gateway delete --nat-gateway-id "$nat_id" --force --wait-for-state TERMINATED --max-wait-seconds 120 || true
  done

  # 5. Delete Service Gateways
  echo "  Deleting Service Gateways..."
  SGW_IDS=$(oci network service-gateway list --compartment-id "$COMPARTMENT_ID" --vcn-id "$vcn_id" --all --query 'data[*].id' --raw-output 2>/dev/null | tr -d '[]" ' | tr ',' '\n')
  for sgw_id in $SGW_IDS; do
    [ -z "$sgw_id" ] && continue
    echo "    Deleting Service GW: $sgw_id"
    oci network service-gateway delete --service-gateway-id "$sgw_id" --force || true
  done

  # 6. Delete Local Peering Gateways
  echo "  Deleting Local Peering Gateways..."
  LPG_IDS=$(oci network local-peering-gateway list --compartment-id "$COMPARTMENT_ID" --vcn-id "$vcn_id" --all --query 'data[*].id' --raw-output 2>/dev/null | tr -d '[]" ' | tr ',' '\n')
  for lpg_id in $LPG_IDS; do
    [ -z "$lpg_id" ] && continue
    echo "    Deleting LPG: $lpg_id"
    oci network local-peering-gateway delete --local-peering-gateway-id "$lpg_id" --force || true
  done

  # 7. Delete non-default Route Tables
  echo "  Deleting non-default Route Tables..."
  RT_IDS=$(oci network route-table list --compartment-id "$COMPARTMENT_ID" --vcn-id "$vcn_id" --all --query 'data[?!"vcn-default-route-table"].id' --raw-output 2>/dev/null | tr -d '[]" ' | tr ',' '\n')
  # Get default RT to skip it
  DEFAULT_RT=$(oci network vcn get --vcn-id "$vcn_id" --query 'data."default-route-table-id"' --raw-output 2>/dev/null)
  ALL_RTS=$(oci network route-table list --compartment-id "$COMPARTMENT_ID" --vcn-id "$vcn_id" --all --query 'data[*].id' --raw-output 2>/dev/null | tr -d '[]" ' | tr ',' '\n')
  for rt_id in $ALL_RTS; do
    [ -z "$rt_id" ] && continue
    [ "$rt_id" = "$DEFAULT_RT" ] && continue
    echo "    Deleting Route Table: $rt_id"
    oci network route-table delete --rt-id "$rt_id" --force --wait-for-state TERMINATED --max-wait-seconds 120 || true
  done

  # 8. Delete non-default Security Lists
  echo "  Deleting non-default Security Lists..."
  DEFAULT_SL=$(oci network vcn get --vcn-id "$vcn_id" --query 'data."default-security-list-id"' --raw-output 2>/dev/null)
  ALL_SLS=$(oci network security-list list --compartment-id "$COMPARTMENT_ID" --vcn-id "$vcn_id" --all --query 'data[*].id' --raw-output 2>/dev/null | tr -d '[]" ' | tr ',' '\n')
  for sl_id in $ALL_SLS; do
    [ -z "$sl_id" ] && continue
    [ "$sl_id" = "$DEFAULT_SL" ] && continue
    echo "    Deleting Security List: $sl_id"
    oci network security-list delete --security-list-id "$sl_id" --force --wait-for-state TERMINATED --max-wait-seconds 120 || true
  done

  # 9. Delete DRG Attachments
  echo "  Deleting DRG Attachments..."
  DRG_ATT_IDS=$(oci network drg-attachment list --compartment-id "$COMPARTMENT_ID" --vcn-id "$vcn_id" --all --query 'data[*].id' --raw-output 2>/dev/null | tr -d '[]" ' | tr ',' '\n')
  for drg_att_id in $DRG_ATT_IDS; do
    [ -z "$drg_att_id" ] && continue
    echo "    Deleting DRG Attachment: $drg_att_id"
    oci network drg-attachment delete --drg-attachment-id "$drg_att_id" --force --wait-for-state DETACHED --max-wait-seconds 120 || true
  done
}

# --- Main: Find and delete all VCNs in compartment ---
echo ""
echo "=== Listing VCNs ==="
VCN_IDS=$(oci network vcn list --compartment-id "$COMPARTMENT_ID" --all --query 'data[*].id' --raw-output 2>/dev/null | tr -d '[]" ' | tr ',' '\n')

if [ -z "$VCN_IDS" ]; then
  echo "No VCNs found in compartment."
  exit 0
fi

for vcn_id in $VCN_IDS; do
  [ -z "$vcn_id" ] && continue
  VCN_NAME=$(oci network vcn get --vcn-id "$vcn_id" --query 'data."display-name"' --raw-output 2>/dev/null)
  echo ""
  echo "Processing VCN: ${VCN_NAME} (${vcn_id})"
  delete_vcn_resources "$vcn_id"

  echo "  Deleting VCN: $vcn_id"
  oci network vcn delete --vcn-id "$vcn_id" --force --wait-for-state TERMINATED --max-wait-seconds 300 || true
done

echo ""
echo "=== Cleanup Complete ==="
```

---

## GitHub Actions Workflow Example

```yaml
name: OCI Cleanup - Delete VCNs and NSGs

on:
  workflow_dispatch:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM

jobs:
  cleanup-oci-networking:
    runs-on: self-hosted  # Azure Container Apps runner
    env:
      OCI_CLI_USER: ${{ secrets.OCI_CLI_USER }}
      OCI_CLI_TENANCY: ${{ secrets.OCI_CLI_TENANCY }}
      OCI_CLI_FINGERPRINT: ${{ secrets.OCI_CLI_FINGERPRINT }}
      OCI_CLI_KEY_CONTENT: ${{ secrets.OCI_CLI_KEY_CONTENT }}
      OCI_CLI_REGION: ${{ secrets.OCI_CLI_REGION }}
      OCI_COMPARTMENT_ID: ${{ secrets.OCI_COMPARTMENT_ID }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install OCI CLI
        run: pip install oci-cli --quiet

      - name: Verify OCI CLI auth
        run: oci iam tenancy get --tenancy-id "$OCI_CLI_TENANCY"

      - name: Run VCN/NSG cleanup
        run: bash ./scripts/oci-cleanup-vcn.sh
```

**Alternative using the Oracle GitHub Action (if not self-hosted):**

```yaml
      - name: Delete NSGs
        uses: oracle-actions/run-oci-cli-command@v1.3.2
        with:
          command: 'network nsg list --compartment-id ${{ secrets.OCI_COMPARTMENT_ID }} --all'
          query: 'data[*].id'
```

---

## References

- OCI API Key Auth: https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm
- OCI CLI Config: https://docs.oracle.com/en-us/iaas/Content/API/Concepts/sdkconfig.htm
- OCI CLI env vars: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/clienvironmentvariables.htm
- oracle-actions/run-oci-cli-command: https://github.com/oracle-actions/run-oci-cli-command
- VCN delete: https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/network/vcn/delete.html
- NSG delete: https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/network/nsg/delete.html
- IAM Policies (virtual-network-family): https://docs.oracle.com/en-us/iaas/Content/Identity/Concepts/commonpolicies.htm

---

## Clarifying Questions

1. **Which compartment(s)** should be targeted? Is there a specific compartment OCID or should the script search all sub-compartments recursively?
2. **Should the script be selective** (e.g., only delete VCNs matching a name pattern like `microhack-*`) or delete ALL VCNs in the compartment?
3. **Service user**: Does an OCI service user already exist with API keys, or does one need to be created?
