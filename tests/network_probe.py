"""Read-only proof of hub-routed networking and both directions of private DNS."""

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
    vnet_id = (f"/subscriptions/{os.environ['TEST_MHCORE_SUB']}/resourceGroups/"
               f"{os.environ['TEST_TR_RG']}/providers/Microsoft.Network/virtualNetworks/"
               f"{os.environ['TEST_TR_VNET']}")
    vnet = arm(vnet_id)["properties"]
    if vnet.get("dhcpOptions", {}).get("dnsServers") != [firewall_ip]:
        raise ValueError("Runner custom DNS must point only to the central firewall")
    peers = vnet.get("virtualNetworkPeerings", [])
    if len(peers) != 1:
        raise ValueError("Runner must peer only with the hub, never directly with Oracle")
    peer = peers[0]["properties"]
    if (peer.get("remoteVirtualNetwork", {}).get("id", "").lower() != hub_id.lower()
            or peer.get("peeringState") != "Connected" or peer.get("allowForwardedTraffic") is not True):
        raise ValueError("Runner hub peering is not connected or does not allow forwarded traffic")
    subnets = vnet.get("subnets", [])
    if not subnets:
        raise ValueError("Runner subnets are missing")
    for subnet in subnets:
        table = arm(subnet["properties"]["routeTable"]["id"])["properties"]
        routes = [route["properties"] for route in table["routes"]]
        for prefix in ("0.0.0.0/0", os.environ["TEST_ODAA_DELEGATED_CIDR"]):
            matching = [route for route in routes if route.get("addressPrefix") == prefix]
            if len(matching) != 1 or matching[0].get("nextHopType") != "VirtualAppliance" or matching[0].get("nextHopIpAddress") != firewall_ip:
                raise ValueError("Runner requires default and exact delegated-subnet routes through firewall")
        # A broader Oracle route can hide an accidental direct connectivity path.
        if any(route.get("addressPrefix") == "192.168.0.0/16" for route in routes):
            raise ValueError("Broad Oracle VNet route is not permitted")
    hub_rg = hub_id.split("/")[4]
    firewalls = json.loads(command([
        "az", "network", "firewall", "list", "--subscription", os.environ["TEST_MHCORE_SUB"],
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
    rulesets_id = hub_id.split("/providers/")[0] + "/providers/Microsoft.Network/dnsForwardingRulesets"
    rulesets = arm(rulesets_id, "2022-07-01")["value"]
    host = os.environ["TEST_DB_HOST"].lower().rstrip(".") + "."
    found = False
    for ruleset in rulesets:
        links = arm(ruleset["id"] + "/virtualNetworkLinks", "2022-07-01")["value"]
        if not any(link["properties"].get("virtualNetwork", {}).get("id", "").lower() == hub_id.lower()
                   and link["properties"].get("provisioningState") == "Succeeded" for link in links):
            continue
        rules = arm(ruleset["id"] + "/forwardingRules", "2022-07-01")["value"]
        for rule in rules:
            properties = rule["properties"]
            domain = properties.get("domainName", "").lower()
            if (domain and (host == domain or host.endswith("." + domain))
                    and properties.get("forwardingRuleState") == "Enabled"
                    and properties.get("targetDnsServers") == [{
                        "ipAddress": os.environ["TEST_ORACLE_DNS_LISTENING_IP"], "port": 53,
                    }]):
                found = True
    if not found:
        raise ValueError("Hub resolver lacks an enabled Oracle-domain rule targeting the actual anchor endpoint")


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


def endpoint_dns():
    database_dns((os.environ["TEST_HUB_RESOLVER_INBOUND_IP"],
                  os.environ["TEST_ORACLE_DNS_LISTENING_IP"]))
    # Compare the Azure-only SOA through Oracle with the actual hub answer.
    zone = os.environ["TEST_CENTRAL_DNS_ZONE_NAME"]
    for tcp in (False, True):
        soa = query(os.environ["TEST_HUB_RESOLVER_INBOUND_IP"], zone, "SOA", tcp)
        if query(os.environ["TEST_ORACLE_DNS_LISTENING_IP"], zone, "SOA", tcp) != soa:
            raise ValueError("Oracle reverse DNS forwarding did not reach the hub resolver")


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--topology"]:
            topology()
            print("HUB_TOPOLOGY_OK")
        elif sys.argv[1:] == ["--dns"]:
            dns()
            print("FIREWALL_DNS_OK")
        elif sys.argv[1:] == ["--endpoint-dns"]:
            endpoint_dns()
            print("BIDIRECTIONAL_DNS_OK")
        elif sys.argv[1:] == ["--hub-dns"]:
            hub_dns()
            print("HUB_DNS_OK")
        else:
            raise ValueError("Unexpected network probe arguments")
    except Exception:
        print("Required hub/DNS network validation failed.", file=sys.stderr)
        sys.exit(1)
