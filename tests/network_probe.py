"""Read-only proof of hub-routed networking and replicated private DNS."""

import ipaddress
import json
import os
import subprocess
import sys


def command(args):
    result = subprocess.run(args, capture_output=True, text=True, check=False, timeout=60)
    if result.returncode:
        raise ValueError("Network probe command failed")
    return result.stdout.strip()


def arm(resource_id, api="2024-05-01"):
    return json.loads(command([
        "az", "rest", "--method", "GET", "--url",
        "https://management.azure.com" + resource_id + "?api-version=" + api,
        "--output", "json",
    ]))


def topology():
    hub_id = os.environ["TEST_HUB_VNET_ID"]
    firewall_ip = os.environ["TEST_FIREWALL_PRIVATE_IP"]
    vnet_id = (f"/subscriptions/{os.environ['TEST_WORKSHOP_SUBSCRIPTION_ID']}/resourceGroups/"
               f"{os.environ['TEST_VM_RESOURCE_GROUP']}/providers/Microsoft.Network/virtualNetworks/"
               f"{os.environ['TEST_VM_VNET_NAME']}")
    vnet = arm(vnet_id)["properties"]
    if vnet.get("dhcpOptions", {}).get("dnsServers") != [firewall_ip]:
        raise ValueError("Participant VM custom DNS must point only to the central firewall")
    peers = vnet.get("virtualNetworkPeerings", [])
    if len(peers) != 1:
        raise ValueError("Participant VM must peer only with the hub, never directly with Oracle")
    peer = peers[0]["properties"]
    if (peer.get("remoteVirtualNetwork", {}).get("id", "").lower() != hub_id.lower()
            or peer.get("peeringState") != "Connected" or peer.get("allowForwardedTraffic") is not True):
        raise ValueError("Participant VM hub peering is not connected or does not allow forwarded traffic")
    subnets = vnet.get("subnets", [])
    if not subnets:
        raise ValueError("Participant VM subnets are missing")
    for subnet in subnets:
        table = arm(subnet["properties"]["routeTable"]["id"])["properties"]
        routes = [route["properties"] for route in table["routes"]]
        for prefix in ("0.0.0.0/0", os.environ["TEST_ODAA_DELEGATED_CIDR"]):
            matching = [route for route in routes if route.get("addressPrefix") == prefix]
            if len(matching) != 1 or matching[0].get("nextHopType") != "VirtualAppliance" or matching[0].get("nextHopIpAddress") != firewall_ip:
                raise ValueError("Participant VM requires default and exact delegated-subnet routes through firewall")
        # A broader Oracle route can hide an accidental direct connectivity path.
        if any(route.get("addressPrefix") == "192.168.0.0/16" for route in routes):
            raise ValueError("Broad Oracle VNet route is not permitted")
    hub_rg = hub_id.split("/")[4]
    firewalls = json.loads(command([
        "az", "network", "firewall", "list", "--subscription", os.environ["TEST_WORKSHOP_SUBSCRIPTION_ID"],
        "--resource-group", hub_rg, "--output", "json",
    ]))
    matching = [fw for fw in firewalls if any(
        config.get("privateIPAddress") == firewall_ip for config in fw.get("ipConfigurations", [])
    )]
    if len(matching) != 1:
        raise ValueError("Expected one central firewall")
    firewall = matching[0]
    if firewall.get("firewallPolicy"):
        settings = arm(firewall["firewallPolicy"]["id"])["properties"]["dnsSettings"]
    else:
        settings = firewall["dnsSettings"]
    if settings.get("enableProxy") is not True or settings.get("servers") != [os.environ["TEST_HUB_RESOLVER_INBOUND_IP"]]:
        raise ValueError("Firewall DNS proxy must forward to central resolver inbound")
    replicated_zone()


def replicated_zone():
    zone_id = os.environ["TEST_ORACLE_DNS_ZONE_ID"]
    prefix = (f"/subscriptions/{os.environ['TEST_ODAA_SUBSCRIPTION_ID']}/resourceGroups/"
              f"{os.environ['TEST_ODAA_RG']}/providers/Microsoft.Network/privateDnsZones/")
    if (not zone_id.lower().startswith(prefix.lower())
            or not zone_id[len(prefix):] or "/" in zone_id[len(prefix):]):
        raise ValueError("Replicated DNS zone must belong to the shared ODAA resource group")
    zone = arm(zone_id, "2020-06-01")
    domain = zone["name"].lower().rstrip(".")
    host = os.environ["TEST_DB_HOST"].lower().rstrip(".")
    if (zone["properties"].get("provisioningState") != "Succeeded"
            or not domain or not host.endswith("." + domain)):
        raise ValueError("Replicated Azure DNS zone is not ready or does not contain the database hostname")
    links = arm(zone_id + "/virtualNetworkLinks", "2020-06-01")["value"]
    if not any(
        link["properties"].get("virtualNetwork", {}).get("id", "").lower()
        == os.environ["TEST_HUB_VNET_ID"].lower()
        and link["properties"].get("provisioningState") == "Succeeded"
        and link["properties"].get("virtualNetworkLinkState") == "Completed"
        and link["properties"].get("registrationEnabled") is False
        for link in links
    ):
        raise ValueError("Replicated Azure DNS zone lacks a completed, non-registering hub VNet link")
    label = host[:-(len(domain) + 1)]
    record = arm(zone_id + "/A/" + label, "2020-06-01")["properties"]
    if {r["ipv4Address"] for r in record.get("aRecords", [])} != {os.environ["TEST_DB_IP"]}:
        raise ValueError("Replicated DNS A record does not match the actual OCI database node")


def query(server, host, kind="A", tcp=False):
    ipaddress.ip_address(server)
    args = ["dig", "@" + server, host, kind, "+short", "+time=5", "+tries=1"]
    if tcp:
        args.append("+tcp")
    answer = command(args).splitlines()
    if not answer:
        raise ValueError("Required private DNS query returned no answer")
    return answer


def dns():
    database_dns((os.environ["TEST_FIREWALL_PRIVATE_IP"],))


def database_dns(servers):
    host, expected = os.environ["TEST_DB_HOST"], os.environ["TEST_DB_IP"]
    for server in servers:
        for tcp in (False, True):
            if {str(ipaddress.ip_address(value)) for value in query(server, host, tcp=tcp)} != {expected}:
                raise ValueError("DNS endpoint did not return the discovered database address")

def hub_dns():
    zone = os.environ["TEST_CENTRAL_DNS_ZONE_NAME"]
    for tcp in (False, True):
        soa = query(os.environ["TEST_HUB_RESOLVER_INBOUND_IP"], zone, "SOA", tcp)
        if query(os.environ["TEST_FIREWALL_PRIVATE_IP"], zone, "SOA", tcp) != soa:
            raise ValueError("Firewall DNS did not reach the central private zone")


def replicated_dns():
    database_dns((os.environ["TEST_HUB_RESOLVER_INBOUND_IP"],
                  os.environ["TEST_FIREWALL_PRIVATE_IP"]))
    hub_dns()


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--topology"]:
            topology()
            print("HUB_TOPOLOGY_OK")
        elif sys.argv[1:] == ["--dns"]:
            dns()
            print("FIREWALL_DNS_OK")
        elif sys.argv[1:] == ["--replicated-dns"]:
            replicated_dns()
            print("REPLICATED_DNS_OK")
        elif sys.argv[1:] == ["--hub-dns"]:
            hub_dns()
            print("HUB_DNS_OK")
        else:
            raise ValueError("Unexpected network probe arguments")
    except Exception:
        print("Required hub/DNS network validation failed.", file=sys.stderr)
        sys.exit(1)
