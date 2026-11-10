"""Read successful canonical ARM deployments; export only required public outputs."""

import argparse
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys

OUTPUTS = {
    "hubVnetId": "BASE_DB_HUB_VNET_ID",
    "firewallPrivateIp": "BASE_DB_FIREWALL_PRIVATE_IP",
    "dnsResolverInboundIp": "BASE_DB_DNS_RESOLVER_INBOUND_IP",
    "centralDnsZoneName": "BASE_DB_CENTRAL_DNS_ZONE_NAME",
    "centralDnsZoneResourceGroupName": "BASE_DB_CENTRAL_DNS_ZONE_RG",
    "odaaVnetId": "BASE_DB_ODAA_VNET_ID",
    "odaaSubnetId": "BASE_DB_ODAA_SUBNET_ID",
    "resourceAnchorId": "BASE_DB_RESOURCE_ANCHOR_ID",
    "networkAnchorId": "BASE_DB_NETWORK_ANCHOR_ID",
    "networkAnchorZone": "BASE_DB_NETWORK_ANCHOR_ZONE",
    "oracleDnsZoneId": "BASE_DB_ORACLE_DNS_ZONE_ID",
    "ociVcnId": "BASE_DB_OCI_VCN_ID",
}


def public_outputs(deployment):
    properties = deployment["properties"]
    if properties.get("provisioningState") != "Succeeded":
        raise ValueError("Required ARM deployment has not succeeded")
    return properties["outputs"]


def export(deployments, stream):
    if len(deployments) != 4:
        raise ValueError("All four canonical hub/network/anchor/DNS deployment responses are required")
    outputs = {}
    for deployment in deployments:
        for key, value in public_outputs(deployment).items():
            if key in OUTPUTS:
                if key in outputs and outputs[key] != value:
                    raise ValueError("Canonical deployments have inconsistent public outputs")
                outputs[key] = value
    lines = []
    for key, variable in OUTPUTS.items():
        item = outputs[key]
        if item.get("type", "").lower() != "string":
            raise ValueError("Required deployment output must be a public string")
        value = item["value"]
        if not isinstance(value, str) or not value or "\n" in value or "\r" in value:
            raise ValueError("Required deployment output is empty or unsafe for GITHUB_ENV")
        lines.append(f"{variable}={value}\n")
    zone = outputs["networkAnchorZone"]["value"]
    anchor = outputs["networkAnchorId"]["value"]
    lines.append("BASE_DB_NETWORK_ANCHOR_IDS_BY_ZONE=" + json.dumps({zone: anchor}, separators=(",", ":")) + "\n")
    stream.writelines(lines)


def workshop_config():
    config = json.loads((Path(__file__).parent / "workshop_config.json").read_text())
    if tuple(config["participants"]) != ("01", "02", "03", "04", "05", "06", "07"):
        raise ValueError("Workshop requires exactly the static seven participant keys")
    return config


def participant(index):
    config = workshop_config()
    return config, config["participants"][index]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--participant", choices=("01", "02", "03", "04", "05", "06", "07"))
    parser.add_argument("--deployment-id", action="append",
                        help="Explicit canonical ARM deployment ID; read-only GET, never deployment create")
    args = parser.parse_args()
    if args.participant and args.deployment_id:
        parser.error("Select participant or read deployments, not both")
    stream = io.StringIO()
    if args.participant:
        config, user = participant(args.participant)
        values = {
            "participant_name": user["name"], "WORKSHOP_TENANT_ID": config["tenantId"],
            "WORKSHOP_SUBSCRIPTION_ID": config["workshopSubscriptionId"],
            "ODAA_SUBSCRIPTION_ID": config["odaaSubscriptionId"],
            "BASE_DB_VM_NAME": user["vmName"], "BASE_DB_VM_RG": user["vmResourceGroup"],
            "BASE_DB_RESOURCE_GROUP": config["databaseResourceGroup"],
            "BASE_DB_NAME": user["databaseName"],
        }
        stream.writelines(f"{key}={value}\n" for key, value in values.items())
    elif args.deployment_id:
        if len(args.deployment_id) != 4 or len({value.lower() for value in args.deployment_id}) != 4:
            raise ValueError("Four distinct canonical deployment IDs are required")
        deployments = []
        config, _ = participant("01")
        permitted = (r"/subscriptions/(" + config["workshopSubscriptionId"] + "|" + config["odaaSubscriptionId"]
                     + r")(?:/resourceGroups/[^/]+)?/providers/Microsoft\.Resources/deployments/[^/]+")
        for resource_id in args.deployment_id:
            if not re.fullmatch(permitted, resource_id, re.I):
                raise ValueError("Deployment ID must belong to a static workshop subscription")
        for resource_id in args.deployment_id:
            result = subprocess.run([
                "az", "rest", "--method", "GET", "--url",
                "https://management.azure.com" + resource_id + "?api-version=2022-09-01",
                "--output", "json",
            ], capture_output=True, text=True, check=False)
            if result.returncode:
                raise ValueError("Required ARM deployment read failed")
            deployments.append(json.loads(result.stdout))
        export(deployments, stream)
    else:
        # Accept full ARM deployment responses, never just unchecked outputs.
        export(json.load(sys.stdin), stream)
    for variable in ("GITHUB_ENV", "GITHUB_OUTPUT"):
        if os.environ.get(variable):
            with Path(os.environ[variable]).open("a") as target:
                target.write(stream.getvalue())
    if not os.environ.get("GITHUB_ENV") and not os.environ.get("GITHUB_OUTPUT"):
        print(stream.getvalue(), end="")


if __name__ == "__main__":
    main()
