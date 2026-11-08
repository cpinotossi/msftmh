#!/bin/bash
# Run the canonical fixed-version playbook on a local Ubuntu 24.04 machine.
# This changes the local machine; Packer invokes the same playbook on its build VM.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=l
sudo cloud-init status --wait
sudo apt-get update
sudo apt-get install -y ansible-core
sudo ansible-playbook -i localhost, -c local \
    "$(dirname "$(readlink -f "$0")")/../ansible/oracle-tools.yml"
