# How to retrieve the Oracle Database Autonomous Database connection string from ODAA

To connect to the Oracle Database you will need the TNS connection string.

## 📍 Retrieve the connection string via the Azure Portal from the ODAA ADB instance.

1. 🎯 Go to your Oracle Database in Azure Portal, search for "adb" in the search bar on top.
2. 🔍 Select "Oracle Database@Azure" from the search results.
3. 📋 Select "Oracle Autonomous Database Service" from the left menu.
4. 🎪 Select your created ADB instance.
5. 🔗 Select "Connection" from the left menu.
6. 🔒 Select High profile, TLS Authentication=TLS Connection String

## 🔧 Alternative you can use the Azure CLI to retrieve the connection string.

~~~powershell
# Prerequisites (if not already installed)
az extension add --name oracle-database 

$adbName="adbuser02" # replace with your ADB name

# Switch to the subscription where ODAA is deployed
$subODAA="sub-mhodaa" 
az account set --subscription $subODAA

$rgODAA="rg-odaa-shared" # shared resource group for all ODAA resources

# Enable preview features for Oracle Database extension
az config set extension.dynamic_install_allow_preview=true
# Install Oracle Database extension if not already installed
az extension add --name oracle-database
# Retrieve TNS Connection string High profile (TCPS, tlsAuthentication = Server)
$trgConn=az oracle-database autonomous-database show -g $rgODAA -n $adbName --query "connectionStrings.profiles[?consumerGroup=='High' && protocol=='TCPS' && tlsAuthentication=='Server'].value | [0]" -o tsv

echo $trgConn
~~~

Output should look similar to this:

~~~text
(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=zeii0mxy.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=gc2401553d1c7ab_adbuser01_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))
~~~


