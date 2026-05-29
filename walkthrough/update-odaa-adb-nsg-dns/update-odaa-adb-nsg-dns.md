#  Challenge: Update Oracle ADB NSG and DNS Configuration

[Back to workspace README](../../README.md)

##  Network Security Group Configuration

You need to update the Oracle ADB Network Security Group (NSG) with the CIDR range of the VNet where your Virtual Machine is deployed. This can be done via the Azure Portal.

See the [official Oracle documentation about Network Security Groups](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/nsg-manage.htm) for more details about Oracle NSG.

### Find the CIDR of your VM virtual network
Search for "Virtual Network" in the Azure portal.

![VNet address space](./media/adbdns1.png)

### Select your virtual network
Select the virtual network called "vnet-vm-user<USER-NUMBER>".

![VNet address space](./media/adbdns2.png)

Inside the virtual network overview, copy the address space CIDR range
![VNet address space](./media/adbdns3.png)

Now head over to your newly created ODAA Autonomous Database resource and click on the OCI Database URL link called "Go to OCI":
![Azure link to OCI console](media/adbdns4.png)

At the OCI console login page, select the "Entra ID" link:
![OCI login via Entra ID](media/adb20.png)

You will land on the Oracle ADB databases overview page:
![OCI ADB overview page](media/adb21.png)

### Scroll down to the networking section on the ADB homepage.

Press on the link "Network Security Groups" to reach the NSG page.

![OCI ADB networking NSG section](media/adbdns5.png)

### Create NSG Rule
 Under the Tab "Security Rules", press the "Add Rules" button to add an ingress rule.
![OCI ADB NSG add Rule](media/adbdns6.png)

Choose in the Rule as "Source Type" CIDR and add the copied VNet address space of the previous "vnet-vm-user<USER-NUMBER>" into the field. Finally, click the "Add" button to create the rule.
![OCI ADB NSG create Rule CIDR](media/adbdns7.png)

### Add a new private DNS zones A-Record for the ADB database

From the overview portal of the deployed ADB database, copy the FQDN of the "database private url" and Database private IP address both in the section Network.

![ADB database overview](./media/adbdns8.png)

### Move to the resource group rg-vm-userXX

![VM resource group](./media/adbdns9.png)

### Set private DNS 

Add a new DNS A-Records at the existing private DNS "adb.eu-paris-1.oraclecloud.com"

Configure the **Recordsets** as following.

![Private DNS recordsets](./media/adbdns10.png)

---

[Back to workspace README](../../README.md)