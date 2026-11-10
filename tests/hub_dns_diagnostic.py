"""Temporary, private hub diagnostics; never relax participant DNS policies."""

import argparse
import base64
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile

import base_database as db

SUBSCRIPTION = "aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483"
HUB_ID = (f"/subscriptions/{SUBSCRIPTION}/resourceGroups/rg-workshop-hub/providers/"
          "Microsoft.Network/virtualNetworks/vnet-workshop-hub")
TAGS = {"Project": "OracleWorkshop", "ManagedBy": "Bicep", "purpose": "hub-dns-diagnostic"}


def scope():
    owner = os.environ["BASE_DB_OWNER"]
    if not re.fullmatch(r"[0-9]+-[0-9]+", owner):
        raise ValueError("Diagnostic owner must be the workflow run ID and attempt")
    return owner, f"rg-workshop-dns-{owner}"


def exists(group):
    value = db.command(["az", "group", "exists", "--subscription", SUBSCRIPTION, "--name", group])
    if type(value) is not bool:
        raise ValueError("Azure did not return a resource-group existence boolean")
    return value


def require_owned(group, owner):
    resource = db.command([
        "az", "group", "show", "--subscription", SUBSCRIPTION, "--name", group, "--output", "json",
    ])
    expected_id = f"/subscriptions/{SUBSCRIPTION}/resourceGroups/{group}"
    if (resource.get("id", "").lower() != expected_id.lower()
            or any(resource.get("tags", {}).get(k) != v
                   for k, v in {**TAGS, "automation-owner": owner}.items())):
        raise ValueError("Refusing to operate on an unowned diagnostic resource group")


def create():
    owner, group = scope()
    if exists(group):
        raise ValueError("Diagnostic resource group already exists; refusing adoption")
    db.command([
        "az", "group", "create", "--subscription", SUBSCRIPTION, "--name", group,
        "--location", "francecentral", "--tags",
        *[f"{key}={value}" for key, value in {**TAGS, "automation-owner": owner}.items()],
        "--output", "json",
    ])
    with tempfile.TemporaryDirectory(prefix="hub-dns-key-") as directory:
        key = Path(directory) / "key"
        subprocess.run(
            ["ssh-keygen", "-q", "-t", "rsa", "-b", "3072", "-N", "", "-f", str(key)], check=True,
        )
        db.command([
            "az", "deployment", "group", "create", "--subscription", SUBSCRIPTION,
            "--resource-group", group, "--name", "hub-dns-diagnostic",
            "--template-file", str(db.ROOT.parent / "infra/deployments/hub-dns-diagnostic.bicep"),
            "--parameters", f"owner={owner}", f"adminSshPublicKey={key.with_suffix('.pub').read_text().strip()}",
            "--output", "json",
        ])
    print("Private hub diagnostic VM created.")


def validate(response, marker):
    properties = response.get("properties", {})
    view = properties.get("instanceView", {})
    output = view.get("output", "")
    if (properties.get("provisioningState") != "Succeeded"
            or view.get("executionState") != "Succeeded"
            or type(view.get("exitCode")) is not int or view["exitCode"] != 0
            or not isinstance(output, str) or output.splitlines().count(marker) != 1):
        raise ValueError("Required hub DNS diagnostic did not explicitly succeed")
    return marker


def probe(smoke=False):
    owner, group = scope()
    require_owned(group, owner)
    if smoke:
        config = {
            "TEST_HUB_RESOLVER_INBOUND_IP": "10.100.0.132",
            "TEST_FIREWALL_PRIVATE_IP": "10.100.0.4",
            "TEST_CENTRAL_DNS_ZONE_NAME": "basedb.workshop.internal",
        }
    else:
        config = json.loads(Path("base-db-config.json").read_text())
        if config["TEST_HUB_VNET_ID"].lower() != HUB_ID.lower():
            raise ValueError("Discovered DNS configuration belongs to a different hub")
        keys = ("TEST_HUB_RESOLVER_INBOUND_IP", "TEST_FIREWALL_PRIVATE_IP",
                "TEST_CENTRAL_DNS_ZONE_NAME", "TEST_DB_HOST", "TEST_DB_IP")
        config = {key: config[key] for key in keys}
    payload = base64.b64encode((db.ROOT / "network_probe.py").read_bytes()).decode()
    exports = "\n".join(f"export {key}={shlex.quote(value)}" for key, value in config.items())
    mode, marker = ("--hub-dns", "HUB_DNS_OK") if smoke else ("--replicated-dns", "REPLICATED_DNS_OK")
    script = f"""set -eu
cloud-init status --wait >/dev/null
directory="$(mktemp -d)"
trap 'rm -f "$directory/network_probe.py"; rmdir "$directory"' EXIT
printf '%s' '{payload}' | base64 -d > "$directory/network_probe.py"
{exports}
python3 "$directory/network_probe.py" {mode}
"""
    command_id = (f"/subscriptions/{SUBSCRIPTION}/resourceGroups/{group}/providers/"
                  "Microsoft.Compute/virtualMachines/vm-hub-dns-diagnostic/runCommands/hub-dns")
    print(db.execute_run_command(
        command_id, "francecentral", script, {}, Path("hub-dns-run-command.json"),
        lambda response: validate(response, marker),
    ))


def cleanup():
    owner, group = scope()
    if not exists(group):
        print("No diagnostic resource group remains for this run.")
        return
    require_owned(group, owner)
    db.command([
        "az", "group", "delete", "--subscription", SUBSCRIPTION, "--name", group, "--yes",
    ])
    if exists(group):
        raise RuntimeError("Diagnostic resource group still exists after deletion")
    print("Owned diagnostic VM, NIC and disks deleted; shared hub preserved.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("create", "probe", "smoke", "cleanup"))
    action = parser.parse_args().action
    try:
        if action == "create":
            create()
        elif action == "cleanup":
            cleanup()
        else:
            probe(smoke=action == "smoke")
    except (ValueError, RuntimeError, KeyError, OSError, subprocess.SubprocessError) as error:
        parser.exit(1, f"Hub DNS diagnostic failed: {error}\n")
