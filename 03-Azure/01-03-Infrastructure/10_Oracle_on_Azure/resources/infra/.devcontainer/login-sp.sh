#!/bin/bash
set -e

echo "============================================"
echo "Logging in Azure CLI as Service Principal"
echo "============================================"

# Parse terraform.tfvars (single source of truth)
TFVARS_PATH="$(dirname "$0")/../terraform.tfvars"
if [ ! -f "$TFVARS_PATH" ]; then
    echo "ERROR: terraform.tfvars not found at $TFVARS_PATH"
    exit 1
fi

echo "Loading credentials from terraform.tfvars..."
parse_tfvar() {
    grep -E "^${1}\s*=" "$TFVARS_PATH" | sed 's/^[^=]*=\s*"\([^"]*\)".*/\1/' | head -1
}

ARM_CLIENT_ID="$(parse_tfvar client_id)"
ARM_CLIENT_SECRET="$(parse_tfvar client_secret)"
ARM_TENANT_ID="$(parse_tfvar tenant_id)"
ARM_SUBSCRIPTION_ID="$(parse_tfvar vm_subscription_id)"

export ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_TENANT_ID ARM_SUBSCRIPTION_ID

if [ -z "$ARM_CLIENT_ID" ] || [ -z "$ARM_CLIENT_SECRET" ] || [ -z "$ARM_TENANT_ID" ]; then
    echo "ERROR: Missing required fields in terraform.tfvars!"
    echo "  Required: client_id, client_secret, tenant_id"
    exit 1
fi

# Login as service principal
az login --service-principal \
    --username "$ARM_CLIENT_ID" \
    --password "$ARM_CLIENT_SECRET" \
    --tenant "$ARM_TENANT_ID" \
    --output none

# Set subscription if provided
if [ -n "$ARM_SUBSCRIPTION_ID" ]; then
    az account set --subscription "$ARM_SUBSCRIPTION_ID"
fi

echo ""
echo "✅ Logged in as Service Principal:"
az account show --query "{name:name, user:user.name, type:user.type}" -o table

echo ""
echo "✅ Verifying Graph API access for authentication methods..."
az rest --method GET --uri "https://graph.microsoft.com/v1.0/me" --query "displayName" -o tsv 2>/dev/null || echo "(SP doesn't have /me endpoint - this is expected)"

echo ""
echo "============================================"
echo "Dev Container Ready!"
echo "All az and terraform commands will run as SP"
echo "============================================"
