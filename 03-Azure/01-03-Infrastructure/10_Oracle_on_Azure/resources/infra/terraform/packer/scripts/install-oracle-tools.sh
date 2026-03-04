#!/bin/bash
# ===============================================================================
# Oracle Workshop VM Setup Script
# ===============================================================================
# This script installs all Oracle tools and CLIs on Ubuntu 24.04.
# Designed to run during Packer image build.
# ===============================================================================

set -e
export DEBIAN_FRONTEND=noninteractive

echo "==============================================================================="
echo "Oracle Workshop VM Setup - Starting Installation"
echo "==============================================================================="

download_or_die() {
    # Usage: download_or_die <url> <dest>
    local url="$1"
    local dest="$2"
    echo ">>> Downloading: $url"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 5 --retry-delay 5 --connect-timeout 15 --max-time 600 -o "$dest" "$url"
    else
        wget -q "$url" -O "$dest"
    fi
    if [ ! -s "$dest" ]; then
        echo "ERROR: Download failed or empty file: $dest" >&2
        exit 10
    fi
}

# ===============================================================================
# Variables
# ===============================================================================
ORACLE_BASE="/opt/oracle"
INSTANT_CLIENT_DIR="${ORACLE_BASE}/instantclient"
SQLCL_DIR="${ORACLE_BASE}/sqlcl"
RWLOADSIM_DIR="${ORACLE_BASE}/rwloadsim"
WALLET_DIR="${ORACLE_BASE}/wallet"
TNS_ADMIN="${ORACLE_BASE}/network/admin"

ORACLE_IC_VERSION="23.5.0.24.07"
RWLOADSIM_VERSION="3.2.1"
JAVA_VERSION="17"

# ===============================================================================
# System Updates and Base Packages
# ===============================================================================
echo ">>> Installing base packages..."
apt-get update
apt-get install -y \
    curl wget unzip zip \
    ca-certificates gnupg lsb-release \
    apt-transport-https software-properties-common \
    libaio1t64 libaio-dev \
    vim nano jq git htop tree tmux \
    dnsutils iputils-ping traceroute netcat-openbsd \
    net-tools tcpdump telnet \
    python3 python3-pip python3-venv

# ===============================================================================
# Java JDK Installation
# ===============================================================================
echo ">>> Installing Java ${JAVA_VERSION}..."
apt-get install -y openjdk-${JAVA_VERSION}-jdk

# ===============================================================================
# Create Oracle Directories
# ===============================================================================
echo ">>> Creating Oracle directories..."
mkdir -p "${ORACLE_BASE}" "${INSTANT_CLIENT_DIR}" "${SQLCL_DIR}" \
         "${RWLOADSIM_DIR}" "${WALLET_DIR}" "${TNS_ADMIN}"

# ===============================================================================
# Oracle Instant Client Installation
# ===============================================================================
echo ">>> Downloading Oracle Instant Client ${ORACLE_IC_VERSION}..."
cd /tmp

download_or_die "https://download.oracle.com/otn_software/linux/instantclient/2350000/instantclient-basic-linux.x64-${ORACLE_IC_VERSION}.zip" "/tmp/instantclient-basic.zip"
download_or_die "https://download.oracle.com/otn_software/linux/instantclient/2350000/instantclient-sqlplus-linux.x64-${ORACLE_IC_VERSION}.zip" "/tmp/instantclient-sqlplus.zip"

echo ">>> Extracting Oracle Instant Client..."
unzip -oq /tmp/instantclient-basic.zip -d "${ORACLE_BASE}"
unzip -oq /tmp/instantclient-sqlplus.zip -d "${ORACLE_BASE}"

# Create symlink
IC_EXTRACTED=$(ls -d ${ORACLE_BASE}/instantclient_* 2>/dev/null | head -1)
if [ -z "$IC_EXTRACTED" ]; then
    echo "ERROR: Instant Client extraction failed (no ${ORACLE_BASE}/instantclient_* dir)" >&2
    exit 11
fi
ln -sf "$IC_EXTRACTED" "${INSTANT_CLIENT_DIR}"
echo ">>> Instant Client installed: $IC_EXTRACTED"

# Ensure sqlplus is reachable
if [ ! -x "${INSTANT_CLIENT_DIR}/sqlplus" ]; then
    echo "ERROR: sqlplus not found after extraction: ${INSTANT_CLIENT_DIR}/sqlplus" >&2
    exit 12
fi
ln -sf "${INSTANT_CLIENT_DIR}/sqlplus" /usr/local/bin/sqlplus 2>/dev/null || true

# ===============================================================================
# Oracle SQLcl Installation
# ===============================================================================
echo ">>> Downloading Oracle SQLcl..."
download_or_die "https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-latest.zip" "/tmp/sqlcl.zip"

echo ">>> Extracting SQLcl..."
unzip -oq /tmp/sqlcl.zip -d "${ORACLE_BASE}"
chmod +x "${SQLCL_DIR}/bin/sql" 2>/dev/null || true
ln -sf "${SQLCL_DIR}/bin/sql" /usr/local/bin/sql || true
echo ">>> SQLcl installed"

# ===============================================================================
# rwloadsim / connping Installation
# ===============================================================================
echo ">>> Downloading rwloadsim ${RWLOADSIM_VERSION}..."
download_or_die "https://github.com/oracle/rwloadsim/releases/download/v.${RWLOADSIM_VERSION}/rwloadsim-linux-x86_64-bin-${RWLOADSIM_VERSION}.tgz" "/tmp/rwloadsim.tgz"

echo ">>> Extracting rwloadsim..."
tar -xzf /tmp/rwloadsim.tgz -C "${RWLOADSIM_DIR}" --strip-components=1

# Create symlinks for connping/ociping
if [ ! -x "${RWLOADSIM_DIR}/bin/connping" ]; then
    echo "ERROR: connping not found after rwloadsim extraction: ${RWLOADSIM_DIR}/bin/connping" >&2
    exit 13
fi
ln -sf "${RWLOADSIM_DIR}/bin/connping" /usr/local/bin/connping 2>/dev/null || true
ln -sf "${RWLOADSIM_DIR}/bin/ociping" /usr/local/bin/ociping 2>/dev/null || true
echo ">>> rwloadsim installed"

# ===============================================================================
# Azure CLI Installation
# ===============================================================================
echo ">>> Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# ===============================================================================
# OCI CLI Installation
# ===============================================================================
echo ">>> Installing OCI CLI..."
pip3 install oci-cli --break-system-packages 2>/dev/null || pip3 install oci-cli

# ===============================================================================
# Environment Configuration
# ===============================================================================
echo ">>> Configuring environment..."

cat > /etc/profile.d/oracle-workshop.sh << 'EOF'
# ===============================================================================
# Oracle Environment Variables
# ===============================================================================
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/instantclient
export TNS_ADMIN=/opt/oracle/network/admin
export LD_LIBRARY_PATH=/opt/oracle/instantclient:$LD_LIBRARY_PATH
export PATH=/opt/oracle/instantclient:/opt/oracle/sqlcl/bin:/opt/oracle/rwloadsim/bin:/usr/local/bin:$PATH

# Java
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# Wallet location
export WALLET_DIR=/opt/oracle/wallet
EOF

# ===============================================================================
# Create sample tnsnames.ora
# ===============================================================================
cat > "${TNS_ADMIN}/tnsnames.ora" << 'EOF'
# ===============================================================================
# TNS Names Configuration for Oracle Database@Azure
# ===============================================================================
# 
# HOW TO USE:
# 1. Download your ADB wallet from Azure Portal
# 2. Extract the wallet to: /opt/oracle/wallet/
# 3. Copy tnsnames.ora from wallet here, or set: export TNS_ADMIN=/opt/oracle/wallet
#
# EXAMPLE:
# MYATP_HIGH = (description= 
#   (retry_count=20)(retry_delay=3)
#   (address=(protocol=tcps)(port=1522)(host=HOSTNAME.adb.eu-paris-1.oraclecloud.com))
#   (connect_data=(service_name=SERVICE_NAME_high.adb.oraclecloud.com))
#   (security=(ssl_server_dn_match=yes))
# )
EOF

# ===============================================================================
# Create Workshop MOTD
# ===============================================================================
cat > /etc/motd << 'EOF'
================================================================================
 Oracle Workshop VM - Quick Reference
================================================================================

INSTALLED TOOLS:
----------------
1. Oracle SQL*Plus:       sqlplus user/pass@service
2. Oracle SQLcl:          sql user/pass@service
3. connping/ociping:      connping user/pass@service

AZURE & OCI:
------------
- Azure CLI:              az login
- OCI CLI:                oci session authenticate

DIRECTORIES:
------------
- Oracle Base:            /opt/oracle
- Instant Client:         /opt/oracle/instantclient
- SQLcl:                  /opt/oracle/sqlcl
- TNS Admin:              /opt/oracle/network/admin
- Wallet (place here):    /opt/oracle/wallet

QUICK START:
------------
1. Download your ADB wallet from Azure Portal
2. Upload and extract to: /opt/oracle/wallet/
3. Set TNS_ADMIN: export TNS_ADMIN=/opt/oracle/wallet
4. Connect: sql admin@myatp_high

================================================================================
EOF

# ===============================================================================
# Cleanup
# ===============================================================================
echo ">>> Cleaning up..."
rm -f /tmp/instantclient-basic.zip /tmp/instantclient-sqlplus.zip
rm -f /tmp/sqlcl.zip /tmp/rwloadsim.tgz
apt-get clean
apt-get autoremove -y

# ===============================================================================
# Verification
# ===============================================================================
echo ""
echo "==============================================================================="
echo "Installation Summary"
echo "==============================================================================="
echo -n "Java:      "; java -version 2>&1 | head -1 || echo "FAILED"
echo -n "SQL*Plus:  "; ls -la /opt/oracle/instantclient/sqlplus 2>/dev/null && echo "OK" || echo "NOT FOUND"
echo -n "SQLcl:     "; /opt/oracle/sqlcl/bin/sql -version 2>/dev/null | head -1 || echo "NOT FOUND"
echo -n "Azure CLI: "; az version 2>&1 | head -1 || echo "FAILED"
echo -n "OCI CLI:   "; oci --version 2>&1 || echo "FAILED"
echo "==============================================================================="
echo "Oracle Workshop VM Setup - COMPLETE"
echo "==============================================================================="
