# 🚀 Challenge 2: Create Azure ODAA [Oracle Database@Azure] Database Resources

[Back to workspace README](../../README.md)

1. Registration of the Azure resource provider in Azure. In our case they are already deployed but can be checked if they are registered - see [Oracle Documentation: Oracle Database at Azure Network Enhancements](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/oracle-database-network-plan)
2. Check the availability of a VNet and delegated subnet for the deployment of the database.
3. Deploy an Oracle ADB in Azure.
   1. Important: Choose the region <font color=red>FRANCE CENTRAL</font>
   2. Use in the Networking section <font color=red>Managed private virtual network IP only</font>
4. Furthermore, you will deploy in this chapter an ADB database via the Azure Portal.
5. Finally, check if the existing VNet peering between the AKS and database subscriptions is available and correctly configured.

## 🛰️ Delegated Subnet Design (Prerequisites)

- ODAA Autonomous Database can be deployed within Azure Virtual Networks, in delegated subnets that are delegated to Oracle Database@Azure.
- Client subnet CIDR falls in general between /27 and /22 (inclusive).
- Valid ranges must use private IPv4 addresses and must avoid the reserved 100.106.0.0/16 and 100.107.0.0/16 blocks used for the interconnect.

A more detailed description can be found here: [Oracle Documentation: Oracle's delegated subnet guidance](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/network-delegated-subnet-design.htm)

**NOTE**: For this Microhack, we have already created the corresponding VNets and subnets, so no additional action is required in this step.

## 🧭 What is an Azure Delegated Subnet?

Azure delegated subnets allow you to delegate exclusive control of a subnet within your VNet to a specific Azure service. When you delegate a subnet, the service can deploy and manage its own network resources (NICs, endpoints, routing) within that subnet without requiring you to provision each resource manually. Traffic still flows privately over your VNet, and you remain in control of higher-level constructs like NSGs and route tables.

## Verify if the Deletagted Subnet is Available for ODAA

The delegated subnet is part of the VNet inside your ODAA subscription.

### Log in to the Azure Portal
[Azure portal](https://portal.azure.com).

## Search for Resource Groups "rg-odaa-shared"
![Search Resource Group](media/adb5.png)

### Click on virtual Network Resource "vnet-odaa-shared"
![Select VNet](media/adb6.png)

### In the VNet overview
You find under the sub-menu Settings the menu Subnets. In the menu Subnets, you see the subnet and inside the table the delegation for "Oracle.Database/networkAttachments".
   ![Overview delegated subnet to Oracle.Database/networkAttachments](media/adb7.png)


## 🛠️ Create an ODAA Autonomous Database Instance

### In the Azure portal, search for Oracle Services and select **Oracle Database@Azure**. 
![Azure portal Oracle Database@Azure](media/adb8.png)

### Select **Create Oracle Autonomous Database** and "create" to start the creation of the Autonomous Database.
![Azure portal Oracle Autonomous Database](media/adb9.png)

### Basics Tab
- Subscription: Select "sub-mhodaa"
- Resource Group: Select "rg-odaa-shared"
- Database name: adbuser<USER-NUMBER>
- Region: France Central
![Azure portal Oracle Autonomous Database Basics](media/adb10.png)

### Configuration Tab
> [!IMPORTANT]
>
> Setup the ADB exactly with the following settings:
>
> **ADB Deployment Settings:**
> 1. Workload type: **Transaction Processing**
> 2. Database version: **26ai**
> 3. ECPU Count: **2**
> 4. Compute auto scaling: **off**
> 5. Storage: **20 GB**
> 6. Storage autoscaling: **off**
> 7. Backup retention period in days: **1 day**
> 8. Administrator password: (do not use '!' inside your password, (example Passw0rd1234))
> 9. License type: **License included**
> 10. Oracle database edition: **Enterprise Edition**

![An image of the Oracle Autonomous database setting is shown here.](media/adb11.png)

### Network Tab

Choose for the connectivity the Access type: Managed private virtual network IP only.
Virual Network: vnet-odaa-shared
Subnet: snet-odaa-delegated

![An image of the Oracle Autonomous database setting is shown here.](media/adb12.png)

### Maintenance Tab

Keep as it is.

![An image of the Oracle Autonomous database setting is shown here.](media/adb13.png)

### Consent Tab

Agree.

![An image of the Oracle Autonomous database setting is shown here.](media/adb14.png)

### Tags Tab

Keep as it is.

### Final Summary of the ADB Shared Settings

Review the final summary and click "Create".

![An image of the Oracle Autonomous database setting is shown here.](media/adb15.png)

### Deployment finished

The deployment will take between 10 to 15 minutes.

![ODAA deployment in progress](media/adb16.png)

After the deployment is finished, click the blue button "go to resource".

![ODAA deployment in progress](media/adb17.png)

Inside the resource group select your newly created ADB resource and open it.

![ODAA deployment in progress](media/adb18.png)

### Further Reading

Complete documentation is available under the following links.

[Oracle Documentation: Create an Autonomous Database](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/azucr-create-autonomous-database.html)

## Check the Created ADB in OCI Console

After the ADB was deployed successfully, check if the ADB is visible on the Azure Portal and OCI side. Important to mention on the OCI side is that the region is set to ***France Central*** and the Compartment is chosen properly.


For Oracle Database@Azure, the OCI console is mainly needed for “Oracle-side” lifecycle and integration tasks that still live in OCI, not in the Azure portal:

Tenant / identity / policy management

Managing OCI tenancy, compartments, IAM policies, and user access that relate to the Oracle-managed parts of the service.
Networking and integration on the OCI side

Viewing and managing OCI VCNs, subnets, NSGs/Security Lists, and routes that participate in the private dark‑fiber connectivity with Azure.
Advanced Oracle platform services

Using OCI-native services that integrate with Oracle Database@Azure (e.g., GoldenGate, Data Guard configurations that are exposed via OCI, logging/monitoring integrations).
Support, diagnostics, and observability

Accessing OCI-native logs, metrics, events, and support tools when Oracle asks you to verify or adjust something from the OCI side.

In short: day‑to‑day database and app operations happen in Azure and the Azure portal; the OCI console is needed when you touch the underlying Oracle/OCI tenancy, networking, or advanced Oracle platform services that sit “behind” Oracle Database@Azure.

To access the OCI console, use the following link after you are logged in to the Azure portal under your newly created ODAA Autonomous Database resource:
![Azure link to OCI console](media/adb19.png)

At the OCI console login page, select the "Entra ID" link:
![OCI login via Entra ID](media/adb20.png)

You will land on the Oracle ADB databases overview page:
![OCI ADB overview page](media/adb21.png)

---

[Back to workspace README](../../README.md)