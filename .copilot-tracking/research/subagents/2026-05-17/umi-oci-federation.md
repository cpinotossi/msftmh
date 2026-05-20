# Research: Azure UMI Federation to OCI

## Research Questions

1. Can OCI accept Azure AD/Entra ID tokens via OIDC federation (OCI Workload Identity)?
2. Does Oracle Database@Azure (ODAA) multicloud link provide cross-cloud authentication?
3. Can Azure issue tokens that OCI would accept (Azure WIF → OCI)?
4. What are practical alternatives if direct federation doesn't exist?

## Context

- Azure Container Apps Job with UMI `id-odaamh-github-runner` (Client ID: `baa16eba-50d6-47b2-bc78-c5dbb2f12e09`)
- OCI Tenancy OCID: `ocid1.tenancy.oc1..aaaaaaaarkr3tvxxmzwueaz3dazimmlsoqk2nc6j77vg33jinbnaupdnokxa`
- Oracle Database@Azure (ODAA) multicloud setup with linked tenancies
- Goal: Delete OCI VCNs and NSGs from GitHub Actions on Azure without OCI API key secrets

---

## Findings

### 1. OCI Workload Identity Federation — Does NOT Support Azure AD/Entra ID Tokens

**Answer: No — OCI cannot accept Azure AD tokens for programmatic API access.**

OCI supports the following SDK/CLI authentication methods:

| Method | Use Case | Applicable? |
|--------|----------|-------------|
| API Key-based | Config file with user OCID, tenancy OCID, fingerprint, private key | Yes (traditional) |
| Session Token-based | Temporary, requires browser login | No (interactive) |
| Instance Principal | OCI compute instances only (uses instance metadata service at 169.254.169.254) | No (Azure workload) |
| Resource Principal | OCI-hosted resources (Functions, OKE pods) | No (Azure workload) |

**OCI's Workload Identity Federation** exists but is scoped exclusively to **OKE (Oracle Kubernetes Engine)** pods running inside OCI. It allows Kubernetes service account tokens from OKE clusters to be exchanged for OCI IAM credentials. It does **not** accept tokens from external OIDC providers like Azure AD, GitHub Actions, or any non-OCI identity system.

**OCI's SAML federation with Azure AD** (documented at `docs.oracle.com/en-us/iaas/Content/Identity/Tasks/federatingADFSazure.htm`) is for **interactive user SSO** to the OCI Console only. It does not enable programmatic API access for service principals or managed identities.

### 2. Oracle Database@Azure — No Cross-Cloud Programmatic Authentication Mechanism

**Answer: No — ODAA does not provide Azure → OCI programmatic identity bridging.**

The ODAA multicloud link provides:

- **Identity federation (SAML SSO)** — Azure users can sign in to OCI Console using Azure AD credentials
- **Oracle Identity Connector** — Registers OCI Exadata VMs as Azure Arc-enabled servers, giving OCI VMs a managed identity in Azure (direction: OCI → Azure, NOT Azure → OCI)
- **Azure Arc integration** — Used for Azure Key Vault TDE integration, allowing OCI database VMs to access Azure Key Vault using managed identity
- **Terraform providers** — The multicloud landing zone uses AzureRM, AzureAD, AzAPI, and OCI providers with separate authentication for each

The Identity Connector bridges OCI → Azure (OCI VMs get Azure managed identities). There is **no reverse bridge** (Azure workloads getting OCI credentials).

### 3. Azure Workload Identity Federation → OCI — Not Supported

**Answer: No — OCI does not accept Azure-issued tokens for API authentication.**

Unlike AWS (which accepts GitHub OIDC tokens via STS AssumeRoleWithWebIdentity) and Azure (which accepts GitHub OIDC tokens via Workload Identity Federation), OCI has **no equivalent token exchange endpoint** that accepts external OIDC tokens.

- OCI does not have a Security Token Service that exchanges external OIDC tokens for OCI credentials
- GitHub Actions OIDC support is available for Azure, AWS, GCP, and HashiCorp Vault — but NOT OCI
- The official `oracle-actions/run-oci-cli-command` GitHub Action requires traditional API key credentials (`OCI_CLI_USER`, `OCI_CLI_TENANCY`, `OCI_CLI_FINGERPRINT`, `OCI_CLI_KEY_CONTENT`, `OCI_CLI_REGION`) stored as GitHub Secrets

### 4. Recommended Alternative: Azure Key Vault with UMI

**Since direct federation is not possible, the best approach is to store OCI API key credentials in Azure Key Vault and retrieve them using the UMI.**

#### Recommended Architecture

```
GitHub Actions Runner (Azure Container Apps Job)
  → UMI authenticates to Azure Key Vault
    → Retrieves OCI API key components (private key, fingerprint, user OCID, tenancy OCID)
      → Configures OCI CLI/SDK with retrieved credentials
        → Calls OCI APIs (delete VCNs, NSGs)
```

#### Implementation Steps

1. **Generate OCI API signing key** for a dedicated OCI user or service account
2. **Store in Azure Key Vault**:
   - Secret: `oci-api-private-key` (PEM content)
   - Secret: `oci-fingerprint`
   - Secret: `oci-user-ocid`
   - Secret: `oci-tenancy-ocid`
   - Secret: `oci-region`
3. **Grant UMI access** to Key Vault secrets (Key Vault Secrets User role)
4. **In GitHub Actions workflow**:
   - Use UMI to authenticate to Azure (no GitHub secrets needed for Azure)
   - Retrieve OCI credentials from Key Vault using `az keyvault secret show`
   - Set OCI CLI environment variables
   - Execute OCI CLI commands

#### Advantages Over GitHub Secrets

- Centralized credential management in Azure Key Vault
- UMI-based access (no secrets stored in GitHub)
- Key rotation can be automated with Key Vault policies
- Audit trail via Key Vault logging
- Credentials never leave the Azure plane except at runtime

#### Alternative: OCI Vault via ODAA Link

Not viable — accessing OCI Vault still requires OCI API authentication first (chicken-and-egg problem).

---

## References

- OCI SDK Authentication Methods: https://docs.oracle.com/en-us/iaas/Content/API/Concepts/sdk_authentication_methods.htm
- OCI Federation with Azure AD (SAML SSO): https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/federatingADFSazure.htm
- OCI Instance Principals: https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm
- OCI Federation concepts: https://docs.oracle.com/en-us/iaas/Content/Identity/Concepts/federation.htm
- Oracle Database@Azure IAM guidance: https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/oracle-on-azure/oracle-iam-odaa
- Oracle Identity Connector (Arc integration): https://learn.microsoft.com/azure/oracle/oracle-db/manage-oracle-transparent-data-encryption-azure-key-vault
- Oracle multicloud landing zone Terraform: https://github.com/oci-landing-zones/terraform-oci-multicloud-azure
- GitHub Actions OIDC overview: https://docs.github.com/en/actions/concepts/security/openid-connect
- oracle-actions/run-oci-cli-command (requires API key secrets): https://github.com/oracle-actions/run-oci-cli-command

---

## Follow-on Questions (Out of Scope)

- Will Oracle add external OIDC provider support for workload identity in the future?
- Can the OCI OKE workload identity federation be extended to accept tokens from non-OKE issuers?
- Is there an undocumented OCI STS endpoint that could be used?

## Clarifying Questions

None — research is conclusive based on available documentation.
