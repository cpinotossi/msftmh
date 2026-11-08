"""Read-only checks for the two fixed workshop v7 configurations."""

import argparse
import json
import subprocess


SUBSCRIPTION = "aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483"
LOCATION = "francecentral"
CONFIGURATIONS = {
    "build": ("Standard_D4as_v7", 1, None),
    "users": ("Standard_D2as_v7", 7, "2"),
}


def normalize(value: str) -> str:
    return "".join(value.lower().split())


def require_nvme_image(image: dict) -> None:
    features = {feature["name"]: feature["value"] for feature in image.get("features", [])}
    controllers = normalize(features.get("DiskControllerTypes", "")).split(",")
    if image.get("architecture") != "x64" or image.get("hyperVGeneration") != "V2" or "nvme" not in controllers:
        raise SystemExit("The image definition/source must be x64, Gen2 and explicitly support NVMe")


def verify_capacity(skus: list[dict], usage: list[dict], mode: str) -> None:
    size, count, zone = CONFIGURATIONS[mode]
    candidates = [sku for sku in skus if sku["name"] == size]
    if len(candidates) != 1:
        raise SystemExit(f"Expected exactly one SKU response for {size}")
    sku = candidates[0]
    for restriction in sku.get("restrictions", []):
        kind = restriction["type"]
        if kind == "Location":
            raise SystemExit(f"{size} is regionally restricted in France Central")
        if kind != "Zone":
            raise SystemExit(f"Unrecognized SKU restriction: {kind}")
        blocked = restriction.get("restrictionInfo", {}).get("zones")
        if not isinstance(blocked, list):
            raise SystemExit("Cannot determine the zones blocked by the SKU restriction")
        if zone in blocked:
            raise SystemExit(f"{size} is restricted in zone {zone}")
    if zone is not None:
        locations = [info for info in sku.get("locationInfo", []) if normalize(info["location"]) == LOCATION]
        if len(locations) != 1 or zone not in locations[0].get("zones", []):
            raise SystemExit(f"{size} does not advertise support for zone {zone}")
    capabilities = {entry["name"]: entry["value"] for entry in sku["capabilities"]}
    if capabilities.get("CpuArchitectureType") != "x64" or "V2" not in capabilities.get("HyperVGenerations", "").split(","):
        raise SystemExit("The fixed SKU must support x64/Gen2")
    if "nvme" not in normalize(capabilities.get("DiskControllerTypes", "")).split(","):
        raise SystemExit("The fixed SKU must support the NVMe controller")
    needed = int(capabilities["vCPUs"]) * count
    quotas = {normalize(item["name"]["value"]): item for item in usage}
    for family in (sku["family"], "cores"):
        quota = quotas.get(normalize(family))
        if quota is None or int(quota["limit"]) - int(quota["currentValue"]) < needed:
            raise SystemExit(f"Insufficient {family} quota for {count} {size} VMs ({needed} vCPUs)")
    print(f"{size}: quota for {count} VM(s) verified; zone {zone or 'regional build'}. Physical allocation is not guaranteed.")


def azure_json(*arguments: str):
    result = subprocess.run(
        ["az", *arguments, "--subscription", SUBSCRIPTION, "--output", "json"],
        check=False, capture_output=True, text=True, timeout=120,
    )
    if result.returncode:
        raise SystemExit(result.stderr.strip() or f"Azure CLI failed with exit code {result.returncode}")
    return json.loads(result.stdout)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=CONFIGURATIONS)
    mode = parser.parse_args().mode
    size = CONFIGURATIONS[mode][0]
    definition = azure_json(
        "sig", "image-definition", "show", "--resource-group", "rg-workshop-images",
        "--gallery-name", "gal_oracle_workshop", "--gallery-image-definition", "oracle-workshop-vm",
    )
    require_nvme_image(definition)
    if mode == "build":
        require_nvme_image(azure_json(
            "vm", "image", "show", "--location", LOCATION,
            "--urn", "Canonical:ubuntu-24_04-lts:server:24.04.202610250",
        ))
    verify_capacity(
        azure_json("vm", "list-skus", "--location", LOCATION, "--resource-type", "virtualMachines", "--size", size, "--all"),
        azure_json("vm", "list-usage", "--location", LOCATION),
        mode,
    )


if __name__ == "__main__":
    main()
