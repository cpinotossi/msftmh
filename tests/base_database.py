"""Fail-closed Base Database@Azure test orchestration (stdlib plus az/oci CLIs).

ARM contract: Oracle.Database stable/2025-09-01/openapi.json in
https://github.com/Azure/azure-rest-api-specs/tree/main/specification/oracle/resource-manager/Oracle.Database/OracleDatabase
Base DB has no ARM dbNodes/PDB children in this API. OCI Database 20160918
DbNode.vnicId and PluggableDatabase.connectionStrings are the endpoint authority.
"""

import argparse
import base64
import io
import ipaddress
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import tarfile
import time
from urllib.parse import urlencode, urlparse

from export_shared_config import workshop_config

API = "2025-09-01"
ARM = "https://management.azure.com"
TAGS = {"workshop": "odaa", "managed-by": "workshop-base-db"}
ROOT = Path(__file__).resolve().parent
EXPECTED_TESTS = 13


def command(args):
    result = subprocess.run(args, capture_output=True, text=True, check=False)
    if result.returncode:
        # Do not echo az/oci responses: request bodies and credentials may be included.
        raise RuntimeError(f"{args[0]} command failed (exit {result.returncode}); no success assumed")
    try:
        return json.loads(result.stdout) if result.stdout.strip() else {}
    except json.JSONDecodeError:
        raise RuntimeError(f"{args[0]} returned invalid JSON") from None


def rest(method, path, body=None):
    url = path if path.startswith("https://") else ARM + path
    if urlparse(url).netloc != "management.azure.com":
        raise ValueError("Unexpected ARM pagination origin")
    if "api-version=" not in url:
        url += ("&" if "?" in url else "?") + "api-version=" + API
    args = ["az", "rest", "--method", method, "--url", url, "--output", "json"]
    if body is None:
        return command(args)
    # Passwords are neither command arguments nor Run Command parameters/logs.
    body_path = Path(".base-db-request.json")
    fd = os.open(body_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(body, stream)
        return command(args + ["--body", "@" + str(body_path)])
    finally:
        body_path.unlink()


def listing(path):
    items = []
    while path:
        page = rest("GET", path)
        if not isinstance(page.get("value"), list):
            raise RuntimeError("ARM list response lacks value array")
        items.extend(page["value"])
        path = page.get("nextLink")
    return items


def owned(resource, owner=None):
    tags = resource.get("tags", {})
    return all(tags.get(k) == v for k, v in TAGS.items()) and (
        owner is None or tags.get("automation-owner") == owner
    )


def wait_ready(resource_id, timeout=7200):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        resource = rest("GET", resource_id)
        state = resource["properties"].get("provisioningState")
        if state in ("Failed", "Canceled"):
            raise RuntimeError("Base DB provisioning failed")
        if state == "Succeeded":
            return resource
        time.sleep(30)
    raise TimeoutError("Base DB provisioning did not succeed before the deadline")


def wait_deleted(resource_id, collection, timeout=7200):
    # Listing avoids treating an arbitrary GET failure as an expected 404.
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if not any(r["id"].lower() == resource_id.lower() for r in listing(collection)):
            return
        time.sleep(20)
    raise TimeoutError("Resource deletion was not verified")


def metadata(subscription, shape, version, zone, compute_model, compute, storage):
    if shape != "VM.BaseDB.x86":
        raise ValueError("This Single Node test requires the regionally advertised VM.BaseDB.x86 shape")
    if not version or not zone or compute is None or storage is None:
        raise ValueError("Explicit version, zone, compute and storage are required")
    if compute < 1 or not 256 <= storage <= 40960:
        raise ValueError("Compute must be positive; storage must be 256..40960 GB")
    prefix = f"/subscriptions/{subscription}/providers/Oracle.Database/locations/francecentral"
    shapes = listing(prefix + "/dbSystemShapes?" + urlencode({"zone": zone}))
    matches = [r["properties"] for r in shapes if r["properties"].get("shapeName") == shape]
    if len(matches) != 1:
        raise ValueError("Selected shape is not uniquely available in France Central / selected zone")
    limits = matches[0]
    if limits.get("shapeFamily") != "VIRTUALMACHINE":
        raise ValueError("Regional metadata must confirm the BaseDB virtual-machine shape family")
    minimum_nodes, maximum_nodes = limits.get("minimumNodeCount"), limits.get("maximumNodeCount")
    if minimum_nodes is None or maximum_nodes is None:
        raise ValueError("Regional metadata did not confirm single-node bounds")
    if not (minimum_nodes <= 1 <= maximum_nodes):
        raise ValueError("Selected regional shape does not support a single node")
    if limits.get("computeModel") != compute_model:
        raise ValueError("Regional metadata must explicitly confirm the selected compute model")
    if compute_model == "ECPU":
        if not 4 <= compute <= 256:
            raise ValueError("ECPU count must be 4..256")
    elif compute_model != "OCPU":
        raise ValueError("Explicit ECPU or OCPU compute model is required")
    # These limits use the metadata's verified computeModel; never convert units.
    minimum = limits.get("minimumCoreCount")
    maximum = limits.get("availableCoreCount")
    increment = limits.get("coreCountIncrement")
    if any(type(value) is not int for value in (minimum, maximum, increment)) or increment < 1:
        raise ValueError("Regional metadata did not provide verifiable compute bounds")
    if not (minimum <= compute <= maximum) or (compute - minimum) % increment:
        raise ValueError("Compute count violates regional shape bounds or increment")
    versions = listing(prefix + "/dbSystemDbVersions?" + urlencode({
        "storageManagement": "LVM", "shapeFamily": limits["shapeFamily"],
    }))
    selected = [r["properties"] for r in versions if r["properties"].get("version") == version]
    if len(selected) != 1 or selected[0].get("supportsPdb") is not True:
        raise ValueError("Explicit version is unavailable or does not advertise PDB support")
    if selected[0].get("isPreviewDbVersion") is True:
        raise ValueError("Preview database versions are not used by this workshop")
    print("Regional shape/version preflight passed (no version substitution).")


def ids(subscription):
    config = workshop_config()
    if subscription != config["odaaSubscriptionId"]:
        raise ValueError("BaseDB must use the fixed ODAA subscription")
    name = os.environ["BASE_DB_RESOURCE_GROUP"]
    system_name = os.environ["BASE_DB_NAME"]
    if name != config["databaseResourceGroup"]:
        raise ValueError("Test DB must use the shared ODAA resource group")
    permitted = {name for user in config["participants"].values()
                 for name in (user["databaseName"], user["workshopDatabaseName"])}
    if system_name not in permitted:
        raise ValueError("DB must use an assigned workshop or reserved test database name")
    group = f"/subscriptions/{subscription}/resourceGroups/{name}"
    provider = group + "/providers/Oracle.Database"
    return group, provider, provider + "/dbSystems/" + system_name


def central_anchor(args):
    anchors = json.loads(os.environ["BASE_DB_NETWORK_ANCHOR_IDS_BY_ZONE"])
    anchor_id = anchors[args.zone]
    resource_id = os.environ["BASE_DB_RESOURCE_ANCHOR_ID"]
    config = workshop_config()
    if args.subscription != config["odaaSubscriptionId"]:
        raise ValueError("Central anchors must use the fixed ODAA subscription")
    prefix = f"/subscriptions/{args.subscription}/resourceGroups/{config['databaseResourceGroup']}/providers/Oracle.Database/"
    for value, kind in ((anchor_id, "networkAnchors"), (resource_id, "resourceAnchors")):
        if not re.fullmatch(re.escape(prefix) + kind + r"/[^/]+",
                            value, re.I):
            raise ValueError("Central anchor ID must belong to the shared ODAA resource group")
    anchor = rest("GET", anchor_id)
    props = anchor["properties"]
    if (props.get("provisioningState") != "Succeeded" or anchor.get("zones") != [args.zone]
            or props.get("resourceAnchorId", "").lower() != resource_id.lower()):
        raise ValueError("Central network anchor is not ready or zonally compatible")
    resource = rest("GET", resource_id)
    if resource["properties"].get("provisioningState") != "Succeeded":
        raise ValueError("Central resource anchor is not ready")
    if props.get("isOracleToAzureDnsZoneSyncEnabled") is not True:
        raise ValueError("Native Oracle-to-Azure private DNS zone replication is required")
    if props.get("isOracleDnsListeningEndpointEnabled") is not False:
        raise ValueError("Oracle listening must be disabled for the replicated DNS architecture")
    for variable, actual in (
        ("BASE_DB_NETWORK_ANCHOR_ID", anchor_id),
        ("BASE_DB_NETWORK_ANCHOR_ZONE", args.zone),
        ("BASE_DB_OCI_VCN_ID", props.get("ociVcnId")),
        ("BASE_DB_ODAA_SUBNET_ID", props.get("subnetId")),
    ):
        if variable in os.environ and os.environ[variable] != actual:
            raise ValueError("Canonical deployment outputs do not match the actual anchor response")
    if not props.get("ociVcnDnsLabel") or not props.get("ociSubnetId") or not props.get("subnetId"):
        raise ValueError("Anchor lacks authoritative OCI DNS/network identifiers")
    if props.get("cidrBlock") != "192.168.0.0/24":
        raise ValueError("Anchor must use the exact workshop delegated subnet 192.168.0.0/24")
    return anchor_id, resource_id, anchor


def create(args):
    metadata(args.subscription, args.shape, args.version, args.zone, args.compute_model, args.compute, args.storage)
    group, provider, system_id = ids(args.subscription)
    anchor_id, resource_anchor, _ = central_anchor(args)
    system_name = system_id.rsplit("/", 1)[1]
    if any(r["name"].lower() == system_name.lower() for r in listing(provider + "/dbSystems")):
        raise RuntimeError("Test DB already exists; refusing to overwrite or adopt it")
    password = os.environ.get("BASE_DB_SYS_PASSWORD", "")
    ssh_key = os.environ.get("BASE_DB_SSH_PUBLIC_KEY", "")
    if not 9 <= len(password) <= 30 or not re.fullmatch(r"[A-Za-z0-9_#-]+", password) or any(
        sum(bool(re.fullmatch(pattern, char)) for char in password) < 2
        for pattern in (r"[A-Z]", r"[a-z]", r"[0-9]", r"[_#-]")
    ):
        raise ValueError("SYS password fails the documented length/character/class constraints")
    if not ssh_key.startswith("ssh-rsa "):
        raise ValueError("Explicit RSA SSH public key environment variable is required")
    values = {
        "dbSystemName": system_name, "shape": args.shape, "dbVersion": args.version, "zone": args.zone,
        "computeModel": args.compute_model, "computeCount": args.compute,
        "storageSizeGb": args.storage, "sshPublicKey": ssh_key,
        "adminPassword": password, "owner": args.owner,
        "resourceAnchorId": resource_anchor, "networkAnchorId": anchor_id,
    }
    parameters = Path(".base-db-request.json")
    fd = os.open(parameters, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump({
                "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
                "contentVersion": "1.0.0.0",
                "parameters": {k: {"value": v} for k, v in values.items()},
            }, stream)
        command([
            "az", "deployment", "group", "create", "--subscription", args.subscription,
            "--resource-group", group.rsplit("/", 1)[1], "--name", "basedb-test-" + args.owner,
            "--template-file", str(ROOT / "bicep/base-db-test.bicep"),
            "--parameters", "@" + str(parameters), "--output", "json",
        ])
    finally:
        parameters.unlink()
    wait_ready(system_id)


def oci(*args):
    return command(["oci", *args, "--output", "json"])["data"]


def one(items, label):
    if len(items) != 1:
        raise ValueError(f"Expected exactly one {label}; refusing ambiguous discovery")
    return items[0]


def parse_service(descriptor):
    if not isinstance(descriptor, str):
        raise ValueError("Missing PDB connection descriptor")
    if descriptor.lstrip().startswith("("):
        protocols = re.findall(r"\(PROTOCOL\s*=\s*([^)]+)\)", descriptor, re.I)
        hosts = re.findall(r"\(HOST\s*=\s*([^)]+)\)", descriptor, re.I)
        ports = re.findall(r"\(PORT\s*=\s*(\d+)\)", descriptor, re.I)
        services = re.findall(r"\(SERVICE_NAME\s*=\s*([^)]+)\)", descriptor, re.I)
        if protocols != ["TCP"] and [p.upper() for p in protocols] != ["TCP"]:
            raise ValueError("Expected one TCP PDB address")
        host, port, service = one(hosts, "host"), one(ports, "port"), one(services, "PDB service")
    else:
        match = re.fullmatch(r"(?://)?([^:/\s]+):(\d+)/([A-Za-z0-9_.-]+)", descriptor.strip())
        if not match:
            raise ValueError("Unsupported PDB connection descriptor; no service-name guessing")
        host, port, service = match.groups()
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", service):
        raise ValueError("Unexpected service name")
    return host.strip(), int(port), service.strip()


def discover(args):
    _, _, system_id = ids(args.subscription)
    anchor_id, resource_anchor_id, anchor = central_anchor(args)
    system = wait_ready(system_id)
    if not owned(system, args.owner):
        raise ValueError("Refusing discovery of an unowned system")
    props = system["properties"]
    if props.get("networkAnchorId", "").lower() != anchor_id.lower():
        raise ValueError("DB system does not use the selected central network anchor")
    if props.get("lifecycleState") != "Available":
        raise ValueError("DB system is not Available")
    system_ocid = props["ocid"]
    compartment = os.environ["OCI_COMPARTMENT_ID"]
    node = one([n for n in oci("db", "node", "list", "--compartment-id", compartment,
                              "--db-system-id", system_ocid, "--all")
                if n["lifecycle-state"] == "AVAILABLE"], "available DB node")
    vnic = oci("network", "vnic", "get", "--vnic-id", node["vnic-id"])
    ip = str(ipaddress.ip_address(vnic["private-ip"]))
    if not ipaddress.ip_address(ip).is_private:
        raise ValueError("Expected a private database node address")
    # ARM provides the authoritative OCI subnet ID, not a full Oracle domain.
    # Read its actual domain; never append a guessed oraclevcn.com suffix.
    subnet = oci("network", "subnet", "get", "--subnet-id", anchor["properties"]["ociSubnetId"])
    if vnic.get("subnet-id") != anchor["properties"]["ociSubnetId"]:
        raise ValueError("DB node is not in the central anchor OCI subnet")
    domain = subnet["subnet-domain-name"].rstrip(".")
    label = vnic["hostname-label"]
    if (not re.fullmatch(r"[A-Za-z0-9-]+", label)
            or not re.fullmatch(r"(?:[A-Za-z0-9-]+\.)+[A-Za-z0-9-]+", domain)
            or anchor["properties"]["ociVcnDnsLabel"].lower() not in domain.lower().split(".")):
        raise ValueError("Invalid or inconsistent authoritative Oracle DNS hostname/domain")
    hostname = label + "." + domain
    database = one(oci("db", "database", "list", "--compartment-id", compartment,
                       "--db-system-id", system_ocid), "container database")
    pdb = one([p for p in oci("db", "pluggable-database", "list",
                             "--database-id", database["id"], "--all")
               if p["pdb-name"].upper() == "WORKSHOP" and p["lifecycle-state"] == "AVAILABLE"],
              "available WORKSHOP PDB")
    pdb = oci("db", "pluggable-database", "get", "--pluggable-database-id", pdb["id"])
    host, port, service = parse_service(pdb["connection-strings"]["pdb-ip-default"])
    if host != ip or port != props.get("listenerPort"):
        raise ValueError("PDB endpoint does not match the discovered node and ARM listener port")
    if port == 1522 or not (1 <= port <= 65535):
        raise ValueError("Unexpected ADB-style or invalid listener port")
    config = {
        "TEST_ODAA_SUBSCRIPTION_ID": args.subscription,
        "TEST_WORKSHOP_SUBSCRIPTION_ID": args.dns_subscription,
        "TEST_DB_ID": system_id, "TEST_NETWORK_ANCHOR_ID": anchor_id,
        "TEST_RESOURCE_ANCHOR_ID": resource_anchor_id,
        "TEST_DB_SHAPE": args.shape, "TEST_DB_VERSION": args.version,
        "TEST_DB_COMPUTE_MODEL": args.compute_model, "TEST_DB_COMPUTE": str(args.compute),
        "TEST_DB_STORAGE": str(args.storage),
        "TEST_DB_IP": ip, "TEST_DB_HOST": hostname, "TEST_ORACLE_DNS_DOMAIN": domain,
        "TEST_ORACLE_DNS_ZONE_ID": os.environ["BASE_DB_ORACLE_DNS_ZONE_ID"],
        "TEST_FIREWALL_PRIVATE_IP": str(ipaddress.ip_address(os.environ["BASE_DB_FIREWALL_PRIVATE_IP"])),
        "TEST_HUB_RESOLVER_INBOUND_IP": str(ipaddress.ip_address(os.environ["BASE_DB_DNS_RESOLVER_INBOUND_IP"])),
        "TEST_HUB_VNET_ID": os.environ["BASE_DB_HUB_VNET_ID"],
        "TEST_CENTRAL_DNS_ZONE_NAME": os.environ["BASE_DB_CENTRAL_DNS_ZONE_NAME"],
        "TEST_ODAA_DELEGATED_CIDR": anchor["properties"]["cidrBlock"],
        "TEST_ODAA_RG": anchor["properties"]["subnetId"].split("/")[4],
        "TEST_ODAA_VNET": anchor["properties"]["subnetId"].split("/")[8],
        "TEST_DB_PORT": str(port), "TEST_DB_SERVICE": service, "TEST_DB_PDB": pdb["pdb-name"],
        "TEST_VM_RESOURCE_GROUP": args.vm_rg,
        "TEST_VM_VNET_NAME": os.environ["BASE_DB_VM_VNET_NAME"],
    }
    Path("base-db-config.json").write_text(json.dumps(config))


def sql_ingress_rules(config):
    policy = config["oracleSqlIngress"]
    sources = policy["sourceCidrs"]
    expected = [f"10.0.{int(index)}.0/24" for index in config["participants"]]
    if sources != expected or type(policy["destinationPort"]) is not int or policy["destinationPort"] != 1521:
        raise ValueError("SQL ingress must use exactly the seven workshop client /24s and TCP 1521")
    return [{
        "direction": "INGRESS", "protocol": "6", "sourceType": "CIDR_BLOCK",
        "source": source, "isStateless": False,
        "tcpOptions": {"destinationPortRange": {"min": 1521, "max": 1521}},
        "description": "OracleWorkshop: client SQL " + source,
    } for source in sources]


def matches_sql_rule(actual, desired):
    tcp = actual.get("tcp-options") or {}
    return (
        actual.get("direction") == desired["direction"]
        and actual.get("protocol") == desired["protocol"]
        and actual.get("source-type") == desired["sourceType"]
        and actual.get("source") == desired["source"]
        and actual.get("is-stateless") is False
        and actual.get("is-valid") is True
        and tcp.get("destination-port-range") == desired["tcpOptions"]["destinationPortRange"]
        and tcp.get("source-port-range") is None
    )


def configure_network(args):
    config = workshop_config()
    desired = sql_ingress_rules(config)
    _, _, system_id = ids(args.subscription)
    anchor_id, _, anchor = central_anchor(args)
    system = rest("GET", system_id)
    props = system["properties"]
    if (not owned(system, args.owner) or props.get("provisioningState") != "Succeeded"
            or props.get("lifecycleState") != "Available"
            or props.get("networkAnchorId", "").lower() != anchor_id.lower()
            or props.get("listenerPort") != config["oracleSqlIngress"]["destinationPort"]):
        raise ValueError("SQL ingress requires the owned, available database on the selected anchor and port")
    for participant, rule in zip(config["participants"].values(), desired):
        name = "vnet-vm-" + participant["name"]
        vnet_id = (f"/subscriptions/{config['workshopSubscriptionId']}/resourceGroups/"
                   f"{participant['vmResourceGroup']}/providers/Microsoft.Network/virtualNetworks/{name}")
        vnet = rest("GET", vnet_id + "?api-version=2024-05-01")
        if vnet["properties"]["addressSpace"]["addressPrefixes"] != [rule["source"]]:
            raise ValueError("Configured SQL ingress source differs from the actual participant VNet")
    compartment = os.environ["OCI_COMPARTMENT_ID"]
    node = one([n for n in oci("db", "node", "list", "--compartment-id", compartment,
                              "--db-system-id", props["ocid"], "--all")
                if n["lifecycle-state"] == "AVAILABLE"], "available DB node")
    vnic = oci("network", "vnic", "get", "--vnic-id", node["vnic-id"])
    if vnic.get("subnet-id") != anchor["properties"]["ociSubnetId"]:
        raise ValueError("Refusing to modify a DB VNIC outside the selected anchor subnet")
    nsg_id = one(vnic["nsg-ids"], "attached database NSG")
    nsg = oci("network", "nsg", "get", "--nsg-id", nsg_id)
    if (nsg.get("vcn-id") != anchor["properties"]["ociVcnId"]
            or nsg.get("compartment-id") != compartment or nsg.get("lifecycle-state") != "AVAILABLE"):
        raise ValueError("Attached database NSG does not match the anchor VCN and linked compartment")
    actual = oci("network", "nsg", "rules", "list", "--nsg-id", nsg_id, "--all")
    if any((rule.get("description") or "").startswith("OracleWorkshop: client SQL ")
           and not any(matches_sql_rule(rule, want) for want in desired) for rule in actual):
        raise ValueError("Existing workshop SQL rule has drifted; explicit review required before modification")
    missing = [want for want in desired if not any(matches_sql_rule(rule, want) for rule in actual)]
    if args.dry_run:
        print(json.dumps({"nsgId": nsg_id, "missingRules": missing}, indent=2))
        return
    if missing:
        oci("network", "nsg", "rules", "add", "--nsg-id", nsg_id,
            "--security-rules", json.dumps(missing))
    for attempt in range(6):
        actual = oci("network", "nsg", "rules", "list", "--nsg-id", nsg_id, "--all")
        if all(any(matches_sql_rule(rule, want) for rule in actual) for want in desired):
            print(f"Verified seven stateful client SQL ingress rules on the attached DB NSG; added {len(missing)}.")
            return
        if attempt < 5:
            time.sleep(2)
    raise RuntimeError("SQL ingress rules were not verified after the OCI update")


def cleanup(subscription, owner=None, dry_run=False):
    config = workshop_config()
    if subscription != config["odaaSubscriptionId"]:
        raise ValueError("Cleanup must use the fixed ODAA subscription")
    provider = (f"/subscriptions/{subscription}/resourceGroups/{config['databaseResourceGroup']}"
                "/providers/Oracle.Database")
    systems = listing(provider + "/dbSystems")
    permitted = re.escape(provider) + r"/dbSystems/[^/]+"
    selected = [r for r in systems if owned(r, owner) and re.fullmatch(permitted, r["id"], re.I)]
    for resource in selected:
        if not owned(rest("GET", resource["id"]), owner):
            raise ValueError("DB system ownership changed during cleanup")
        print(("Would delete " if dry_run else "Deleting ") + resource["id"])
        if not dry_run:
            rest("DELETE", resource["id"])
            wait_deleted(resource["id"], provider + "/dbSystems")
    # Central anchors and DNS are organizer-owned. Never enumerate/delete them,
    # even if an old deployment left workshop ownership tags on an anchor.


def validate_tap(text, expected=EXPECTED_TESTS):
    lines = text.splitlines()
    plans = [int(m[1]) for line in lines if (m := re.fullmatch(r"1\.\.(\d+)", line))]
    results = [m for line in lines if (m := re.fullmatch(r"(ok|not ok) (\d+) (.+)", line))]
    if plans != [expected] or len(results) != expected:
        raise ValueError("TAP plan/result count mismatch or truncated output")
    if [int(m[2]) for m in results] != list(range(1, expected + 1)):
        raise ValueError("TAP test numbering mismatch")
    if any(m[1] != "ok" or re.search(r"#\s*(skip|todo)\b", m[3], re.I) for m in results):
        raise ValueError("TAP contains failed, skipped or TODO tests")
    if any(line.startswith(("Bail out!", "not ok")) for line in lines):
        raise ValueError("TAP failure")
    if not any("SQL authenticates to the actual PDB" in m[3] for m in results):
        raise ValueError("SQL PDB test missing")


def validate_remote(response):
    properties = response.get("properties", {})
    view = properties.get("instanceView", {})
    if properties.get("provisioningState") != "Succeeded" or view.get("executionState") != "Succeeded":
        raise ValueError("Managed Run Command provisioning/execution status failed or missing")
    if type(view.get("exitCode")) is not int or view["exitCode"] != 0:
        raise ValueError("Remote process exitCode was missing or nonzero")
    stdout = view.get("output", "")
    if re.findall(r"^BASE_DB_TEST_EXIT=(\d+)$", stdout, re.M) != ["0"]:
        raise ValueError("Remote process did not explicitly exit successfully")
    validate_tap(stdout)
    return stdout


def remote(args):
    config = json.loads(Path("base-db-config.json").read_text())
    passwords = {name: os.environ.get(name, "") for name in ("BASE_DB_SYS_PASSWORD", "BASE_DB_TEST_PASSWORD")}
    if not all(passwords.values()):
        raise ValueError("SYS and distinct limited-user password secrets are required")
    if passwords["BASE_DB_SYS_PASSWORD"] == passwords["BASE_DB_TEST_PASSWORD"]:
        raise ValueError("Privileged and test-user passwords must differ")
    archive = io.BytesIO()
    with tarfile.open(fileobj=archive, mode="w:gz") as tar:
        for path in sorted(ROOT.rglob("*")):
            if path.is_file() and (path.suffix in (".bats", ".bash") or path.name in ("run-tests.sh", "sql_probe.py", "provision_sql_user.py", "network_probe.py")):
                tar.add(path, arcname=str(path.relative_to(ROOT)))
    payload = base64.b64encode(archive.getvalue()).decode()
    exports = "\n".join(f"export {key}={shlex.quote(value)}" for key, value in config.items())
    script = f"""set -eu
set +x
cloud-init status --wait >/dev/null
install -d -m 755 /opt/tests
find /opt/tests -maxdepth 1 -name 'challenge-*.bats' -delete
printf '%s' '{payload}' | base64 -d | tar -xz -C /opt/tests
{exports}
credential_file=/etc/oracle-workshop/base-db-test.json
test ! -e "$credential_file" && test ! -L "$credential_file"
trap 'rm -f "$credential_file"' EXIT
trap 'exit 1' HUP INT TERM
python3 /opt/tests/provision_sql_user.py
unset BASE_DB_SYS_PASSWORD BASE_DB_TEST_PASSWORD
set +e
bash /opt/tests/run-tests.sh
rc=$?
printf '\\nBASE_DB_TEST_EXIT=%s\\n' "$rc"
exit "$rc"
"""
    location = command([
        "az", "vm", "show", "--subscription", args.dns_subscription,
        "--resource-group", args.vm_rg, "--name", args.vm_name,
        "--query", "location", "--output", "json",
    ])
    command_id = (
        f"/subscriptions/{args.dns_subscription}/resourceGroups/{args.vm_rg}/providers/"
        f"Microsoft.Compute/virtualMachines/{args.vm_name}/runCommands/base-db-test-{args.owner}"
    )
    print(execute_run_command(
        command_id, location, script, passwords, Path("base-db-run-command.json"), validate_remote,
    ))


def execute_run_command(command_id, location, script, passwords, report_path, validate):
    url = command_id + "?api-version=2024-11-01"
    # Named protectedParameters become Linux environment variables. Values are
    # absent from source.script, public parameters, process argv and artifacts.
    body = {
        "location": location,
        "properties": {
            "source": {"script": script}, "asyncExecution": True,
            "timeoutInSeconds": 1800, "treatFailureAsDeploymentFailure": True,
            "protectedParameters": [{"name": name, "value": value} for name, value in passwords.items()],
        },
    }
    rest("PUT", url, body)
    try:
        deadline = time.monotonic() + 2100
        while time.monotonic() < deadline:
            response = rest("GET", command_id + "?api-version=2024-11-01&$expand=instanceView")
            properties = response.get("properties", {})
            view = properties.get("instanceView", {})
            failed = view.get("executionState") in ("Failed", "Canceled", "TimedOut") or properties.get("provisioningState") in ("Failed", "Canceled")
            succeeded = view.get("executionState") == "Succeeded" and properties.get("provisioningState") == "Succeeded"
            if failed or succeeded:
                # Persist only selected execution fields, never protectedParameters.
                safe_view = {key: view.get(key) for key in ("executionState", "exitCode", "output", "error")}
                for key in ("output", "error"):
                    if isinstance(safe_view[key], str):
                        for secret in passwords.values():
                            safe_view[key] = safe_view[key].replace(secret, "***")
                report = {
                    "properties": {
                        "provisioningState": properties.get("provisioningState"),
                        "instanceView": safe_view,
                    },
                }
                report_path.write_text(json.dumps(report, indent=2))
                return validate(report)
            time.sleep(10)
        raise TimeoutError("Managed Run Command did not finish before the deadline")
    finally:
        rest("DELETE", url)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=(
        "preflight", "create", "discover", "configure-network", "remote", "cleanup", "anchor-check",
    ))
    parser.add_argument("--subscription", default=os.environ.get("ODAA_SUBSCRIPTION_ID"))
    parser.add_argument("--owner", default=os.environ.get("BASE_DB_OWNER"))
    parser.add_argument("--shape", default=os.environ.get("BASE_DB_SHAPE"))
    parser.add_argument("--version", default=os.environ.get("BASE_DB_VERSION"))
    parser.add_argument("--zone", default=os.environ.get("BASE_DB_ZONE"))
    parser.add_argument("--compute-model", default=os.environ.get("BASE_DB_COMPUTE_MODEL"))
    parser.add_argument("--compute", type=int, default=os.environ.get("BASE_DB_COMPUTE"))
    parser.add_argument("--storage", type=int, default=os.environ.get("BASE_DB_STORAGE"))
    parser.add_argument("--dns-subscription", default=os.environ.get("WORKSHOP_SUBSCRIPTION_ID"))
    parser.add_argument("--vm-rg", default=os.environ.get("BASE_DB_VM_RG"))
    parser.add_argument("--vm-name", default=os.environ.get("BASE_DB_VM_NAME"))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if not args.subscription:
        parser.error("Explicit subscription is required")
    if args.action not in ("cleanup", "preflight", "anchor-check") and not args.owner:
        parser.error("Explicit automation owner is required")
    if args.action == "preflight":
        metadata(args.subscription, args.shape, args.version, args.zone, args.compute_model, args.compute, args.storage)
    elif args.action == "create":
        create(args)
    elif args.action == "discover":
        discover(args)
    elif args.action == "configure-network":
        configure_network(args)
    elif args.action == "remote":
        remote(args)
    elif args.action == "cleanup":
        cleanup(args.subscription, args.owner, args.dry_run)
    elif args.action == "anchor-check":
        central_anchor(args)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # All underlying CLI failures have already been sanitized.
        raise SystemExit(f"Base DB automation failed: {error}") from None
