import json
from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
PARTICIPANTS = [f"mhuser{i}" for i in range(1, 8)]


def resources(template):
    entries = template.get("resources", [])
    return list(entries.values()) if isinstance(entries, dict) else entries


def all_resources(template):
    for resource in resources(template):
        yield resource
        nested = resource.get("properties", {}).get("template")
        if nested:
            yield from all_resources(nested)


def of_type(template, resource_type):
    return [
        resource for resource in all_resources(template)
        if resource["type"] == resource_type
    ]


class DeploymentTemplatesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.templates = {}
        for name in (
            "00-github-identity", "02-hub", "02-image-gallery", "03-users", "03-user-vms",
            "04-oracle-network", "05-oracle-connectivity",
            "06-network-anchor", "07-oracle-dns", "hub-dns-diagnostic", "hub-dns-diagnostic-network",
        ):
            result = subprocess.run(
                ["az", "bicep", "build", "--file", str(ROOT / f"{name}.bicep"), "--stdout"],
                capture_output=True, text=True, timeout=120, check=False,
            )
            if result.returncode:
                raise RuntimeError(f"{name} failed to compile:\n{result.stderr}")
            cls.templates[name] = json.loads(result.stdout)

    def test_exactly_seven_participants(self):
        for name in ("03-users", "03-user-vms"):
            with self.subTest(stage=name):
                participants = self.templates[name]["variables"]["participants"]
                names = [item["name"] if isinstance(item, dict) else item for item in participants]
                self.assertEqual(names, PARTICIPANTS)
                self.assertNotIn("userCount", self.templates[name].get("parameters", {}))

    def test_oracle_resources_and_database_writes_share_one_group(self):
        template = self.templates["04-oracle-network"]
        groups = of_type(template, "Microsoft.Resources/resourceGroups")
        self.assertEqual([group["name"] for group in groups], ["rg-odaa-shared"])
        self.assertNotIn("userObjectIds", template["parameters"])
        access = next(resource for resource in resources(template) if resource["name"] == "db-access-shared")
        self.assertEqual(access["resourceGroup"], "rg-odaa-shared")
        assignment = of_type(access["properties"]["template"], "Microsoft.Authorization/roleAssignments")[0]
        self.assertEqual(assignment["properties"]["principalType"], "Group")
        self.assertEqual(access["properties"]["parameters"]["groupObjectId"]["value"],
                         "[parameters('workshopGroupId')]")
        creator = next(role for role in of_type(template, "Microsoft.Authorization/roleDefinitions")
                       if role["properties"]["roleName"] == "Oracle Workshop BaseDB Creator")
        self.assertEqual(creator["properties"]["permissions"][0]["actions"], [
            "Oracle.Database/dbSystems/*", "Microsoft.Resources/deployments/*",
            "Microsoft.Resources/subscriptions/resourceGroups/read",
        ])

    def test_github_bootstrap_has_only_identity_and_approved_rbac(self):
        template = self.templates["00-github-identity"]
        self.assertFalse(template["parameters"]["participantEnvironmentsReady"]["defaultValue"])
        types = {r["type"] for r in all_resources(template)}
        self.assertEqual(types, {
            "Microsoft.Resources/resourceGroups", "Microsoft.Resources/deployments",
            "Microsoft.ManagedIdentity/userAssignedIdentities",
            "Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials",
            "Microsoft.Authorization/roleAssignments",
        })
        identity = of_type(template, "Microsoft.ManagedIdentity/userAssignedIdentities")[0]
        self.assertEqual(identity["name"], "id-workshop-github")
        credentials = of_type(template, "Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials")[0]
        self.assertEqual(credentials["properties"]["issuer"], "https://token.actions.githubusercontent.com")
        self.assertEqual(credentials["properties"]["audiences"], ["api://AzureADTokenExchange"])
        self.assertEqual(credentials["copy"]["batchSize"], 1)
        self.assertIn("participantEnvironmentsReady", credentials["condition"])
        identity_template = next(
            r["properties"]["template"] for r in resources(template)
            if r["type"] == "Microsoft.Resources/deployments" and r["name"] == "github-identity"
        )
        self.assertEqual([s["subject"] for s in identity_template["variables"]["subjects"]], [
            "repo:cpinotossi/msftmh:ref:refs/heads/main",
            *[f"repo:cpinotossi/msftmh:environment:{p}" for p in PARTICIPANTS],
        ])

    def test_phase_a_has_no_oracle_dependency(self):
        for name in ("02-hub", "02-image-gallery", "03-users", "03-user-vms"):
            with self.subTest(stage=name):
                template = self.templates[name]
                self.assertFalse(any(
                    resource["type"].startswith("Oracle.Database/")
                    for resource in all_resources(template)
                ))
                self.assertNotIn("4ce5b5cc-e869-451f-98fc-f50448849ee0", json.dumps(template))
        self.assertEqual(set(self.templates["02-hub"]["parameters"]), {"location"})

    def test_network_stage_does_not_require_image_or_vm(self):
        template = self.templates["03-users"]
        self.assertFalse(of_type(template, "Microsoft.Compute/virtualMachines"))
        self.assertNotIn("vmImageId", template["parameters"])
        self.assertNotIn("adminSshPublicKey", template["parameters"])
        self.assertFalse(of_type(template, "Microsoft.Network/publicIPAddresses"))
        self.assertFalse(of_type(template, "Microsoft.Network/bastionHosts"))

    def test_hub_peerings_are_serialized(self):
        peerings = [
            resource for resource in resources(self.templates["03-users"])
            if resource.get("copy", {}).get("name") == "hubPeerings"
        ]
        self.assertEqual(len(peerings), 1)
        self.assertEqual(peerings[0]["copy"]["mode"], "serial")
        self.assertEqual(peerings[0]["copy"]["batchSize"], 1)

    def test_vm_stage_uses_fixed_image_and_no_public_ip(self):
        template = self.templates["03-user-vms"]
        self.assertTrue(template["parameters"]["vmImageId"]["defaultValue"].endswith("/versions/1.1.0"))
        vm = of_type(template, "Microsoft.Compute/virtualMachines")[0]
        self.assertEqual(vm["properties"]["hardwareProfile"]["vmSize"], "Standard_D2as_v7")
        self.assertEqual(vm["zones"], ["2"])
        self.assertEqual(vm["properties"]["storageProfile"]["diskControllerType"], "NVMe")
        self.assertTrue(vm["properties"]["osProfile"]["linuxConfiguration"]["disablePasswordAuthentication"])
        self.assertFalse(of_type(template, "Microsoft.Network/publicIPAddresses"))
        nic = of_type(template, "Microsoft.Network/networkInterfaces")[0]
        self.assertNotIn("publicIPAddress", nic["properties"]["ipConfigurations"][0]["properties"])
        extension = of_type(template, "Microsoft.Compute/virtualMachines/extensions")[0]
        self.assertEqual(extension["properties"]["type"], "AADSSHLoginForLinux")

    def test_gallery_advertises_nvme(self):
        definition = of_type(self.templates["02-image-gallery"], "Microsoft.Compute/galleries/images")[0]
        features = {feature["name"]: feature["value"] for feature in definition["properties"]["features"]}
        self.assertIn("NVMe", features["DiskControllerTypes"].split(","))
        self.assertEqual(features["SecurityType"], "TrustedLaunchSupported")

    def test_diagnostic_is_private_scoped_and_uses_the_verified_image(self):
        template = self.templates["hub-dns-diagnostic"]
        self.assertEqual(set(template["parameters"]), {"owner", "adminSshPublicKey"})
        self.assertFalse(of_type(template, "Microsoft.Network/publicIPAddresses"))
        self.assertFalse(of_type(template, "Microsoft.Authorization/roleAssignments"))
        vm = of_type(template, "Microsoft.Compute/virtualMachines")[0]
        self.assertNotIn("identity", vm)
        self.assertEqual(vm["zones"], ["2"])
        self.assertEqual(vm["properties"]["hardwareProfile"]["vmSize"], "Standard_D2as_v7")
        self.assertEqual(vm["properties"]["storageProfile"]["diskControllerType"], "NVMe")
        self.assertEqual(vm["properties"]["storageProfile"]["osDisk"]["deleteOption"], "Delete")
        self.assertIn("/versions/1.1.0", vm["properties"]["storageProfile"]["imageReference"]["id"])
        nsg = of_type(template, "Microsoft.Network/networkSecurityGroups")[0]
        rules = {r["name"]: r["properties"] for r in nsg["properties"]["securityRules"]}
        self.assertEqual(rules["DenyAllInbound"]["access"], "Deny")
        self.assertEqual(rules["DenyOtherOutbound"]["access"], "Deny")
        self.assertEqual(rules["AllowDiagnosticDNS"]["destinationPortRange"], "53")
        self.assertEqual(rules["AllowDiagnosticDNS"]["destinationAddressPrefixes"],
                         ["10.100.0.4", "10.100.0.132"])
        hub = of_type(self.templates["02-hub"], "Microsoft.Network/virtualNetworks")[0]
        diagnostic = next(s for s in hub["properties"]["subnets"] if s["name"] == "snet-dns-diagnostic")
        self.assertEqual(diagnostic["properties"]["addressPrefix"], "10.100.1.0/28")
        self.assertFalse(diagnostic["properties"]["defaultOutboundAccess"])
        self.assertIn("routeTable", diagnostic["properties"])

    def test_diagnostic_network_update_preserves_parent_vnet_and_existing_rules(self):
        template = self.templates["hub-dns-diagnostic-network"]
        self.assertEqual({r["type"] for r in all_resources(template)}, {
            "Microsoft.Resources/deployments", "Microsoft.Network/routeTables",
            "Microsoft.Network/firewallPolicies/ruleCollectionGroups",
            "Microsoft.Network/virtualNetworks/subnets",
        })
        subnet = of_type(template, "Microsoft.Network/virtualNetworks/subnets")[0]
        self.assertIn("snet-dns-diagnostic", subnet["name"])
        group = of_type(template, "Microsoft.Network/firewallPolicies/ruleCollectionGroups")[0]
        self.assertIn("diagnostic-egress", group["name"])
        self.assertNotIn("hub-dns-diagnostic-network",
                         [r["name"] for r in of_type(template, "Microsoft.Resources/deployments")])

    def test_central_dns_proxy_and_zone(self):
        template = self.templates["02-hub"]
        policy = of_type(template, "Microsoft.Network/firewallPolicies")[0]
        self.assertEqual(policy["properties"]["dnsSettings"], {
            "enableProxy": True, "servers": ["10.100.0.132"],
        })
        inbound = of_type(template, "Microsoft.Network/dnsResolvers/inboundEndpoints")[0]
        self.assertEqual(inbound["properties"]["ipConfigurations"][0]["privateIpAddress"], "10.100.0.132")
        zone = of_type(template, "Microsoft.Network/privateDnsZones")[0]
        self.assertEqual(zone["name"], "basedb.workshop.internal")
        link = of_type(template, "Microsoft.Network/privateDnsZones/virtualNetworkLinks")[0]
        self.assertFalse(link["properties"]["registrationEnabled"])
        spoke = of_type(self.templates["03-users"], "Microsoft.Network/virtualNetworks")[0]
        self.assertEqual(spoke["properties"]["dhcpOptions"]["dnsServers"], ["[parameters('firewallPrivateIp')]"])
        self.assertFalse(of_type(self.templates["03-users"], "Microsoft.Network/privateDnsZones"))

    def test_spokes_and_firewall_deny_other_clients(self):
        nsg = of_type(self.templates["03-users"], "Microsoft.Network/networkSecurityGroups")[0]
        rules = {rule["name"]: rule["properties"] for rule in nsg["properties"]["securityRules"]}
        for name in ("DenyOtherClientsInbound", "DenyOtherClientsOutbound", "DenyOtherDNS"):
            self.assertEqual(rules[name]["access"], "Deny")
        self.assertEqual(rules["AllowFirewallDNS"]["destinationPortRange"], "53")
        self.assertEqual(rules["DenyAzurePlatformDNS"]["destinationPortRange"], "*")
        self.assertEqual(rules["DenyAzurePlatformDNS"]["sourcePortRange"], "*")
        self.assertEqual(rules["DenyAzurePlatformDNS"]["protocol"], "*")
        collections = of_type(
            self.templates["02-hub"], "Microsoft.Network/firewallPolicies/ruleCollectionGroups",
        )[0]["properties"]["ruleCollections"]
        self.assertEqual(collections[0]["action"]["type"], "Deny")
        self.assertEqual(collections[0]["rules"][0]["sourceAddresses"], "[variables('clientCidrs')]")
        self.assertEqual(collections[0]["rules"][0]["destinationAddresses"], "[variables('clientCidrs')]")

    def test_spoke_permissions_and_shared_reader(self):
        assignments = of_type(self.templates["03-users"], "Microsoft.Authorization/roleAssignments")
        roles = [assignment["properties"]["roleDefinitionId"] for assignment in assignments]
        self.assertTrue(any("b24988ac-6180-42a0-ab88-20f7382dd24c" in role for role in roles))
        self.assertTrue(any("acdd72a7-3385-48ef-bd42-f606fba81ae7" in role for role in roles))
        self.assertFalse(any("8e3af657-a8ff-443c-a75c-2fe8c4bcb635" in role for role in roles))

    def test_organizer_login_is_scoped_to_the_seven_spokes_and_preserves_participant_access(self):
        template = self.templates["03-users"]
        organizer = template["parameters"]["organizerObjectId"]
        self.assertEqual(organizer["minLength"], 36)
        self.assertEqual(organizer["maxLength"], 36)
        self.assertNotIn("defaultValue", organizer)
        access = next(resource for resource in resources(template)
                      if resource.get("copy", {}).get("name") == "access")
        self.assertEqual(access["copy"]["count"], "[length(variables('participants'))]")
        self.assertEqual(access["resourceGroup"],
                         "[format('rg-vm-{0}', variables('participants')[copyIndex()].name)]")
        self.assertEqual(access["properties"]["parameters"]["organizerObjectId"]["value"],
                         "[parameters('organizerObjectId')]")
        assignments = of_type(access["properties"]["template"], "Microsoft.Authorization/roleAssignments")
        self.assertEqual(len(assignments), 2)
        participant, = [assignment for assignment in assignments
                        if "b24988ac-6180-42a0-ab88-20f7382dd24c" in assignment["properties"]["roleDefinitionId"]]
        self.assertEqual(participant["properties"]["principalId"], "[parameters('userObjectId')]")
        admin, = [assignment for assignment in assignments
                  if "1c0163c0-47e6-4577-8991-ea5c82e286e4" in assignment["properties"]["roleDefinitionId"]]
        self.assertEqual(admin["properties"]["principalId"], "[parameters('organizerObjectId')]")
        self.assertEqual(admin["properties"]["principalType"], "User")
        self.assertIn("'organizer-vm-admin-login'", admin["name"])
        self.assertFalse(of_type(self.templates["02-hub"], "Microsoft.Authorization/roleAssignments"))
        user_login, = of_type(self.templates["03-user-vms"], "Microsoft.Authorization/roleAssignments")
        self.assertIn("fb879df8-f326-4884-b1cf-06f3ad86be52", user_login["properties"]["roleDefinitionId"])
        self.assertEqual(user_login["properties"]["principalId"], "[parameters('userObjectId')]")

    def test_exact_oracle_route_is_present_before_phase_b(self):
        route_table = of_type(self.templates["03-users"], "Microsoft.Network/routeTables")[0]
        routes = {route["name"]: route["properties"] for route in route_table["properties"]["routes"]}
        self.assertEqual(routes["oracle-via-hub"]["addressPrefix"], "192.168.0.0/24")
        self.assertEqual(routes["oracle-via-hub"]["nextHopType"], "VirtualAppliance")
        self.assertEqual(routes["internet-via-hub"]["addressPrefix"], "0.0.0.0/0")
        oracle = self.templates["04-oracle-network"]
        vnet = of_type(oracle, "Microsoft.Network/virtualNetworks")[0]
        self.assertIn("routeTable", vnet["properties"]["subnets"][0]["properties"])
        self.assertTrue(of_type(oracle, "Microsoft.Network/routeTables"))

    def test_shared_anchor_uses_native_zone_replication_without_dns_endpoints(self):
        anchor = of_type(self.templates["06-network-anchor"], "Oracle.Database/networkAnchors")[0]
        properties = anchor["properties"]
        self.assertFalse(properties["isOracleDnsListeningEndpointEnabled"])
        self.assertFalse(properties["isOracleDnsForwardingEndpointEnabled"])
        self.assertTrue(properties["isOracleToAzureDnsZoneSyncEnabled"])
        self.assertNotIn("dnsListeningEndpointAllowedCidrs", properties)
        self.assertNotIn("dnsForwardingRules", properties)
        self.assertNotIn("oracleDnsListeningIp", self.templates["06-network-anchor"]["outputs"])

    def test_oci_sql_config_matches_bicep_client_routes_and_firewall(self):
        config = json.loads((ROOT.parents[1] / "tests/workshop_config.json").read_text())
        policy = config["oracleSqlIngress"]
        rule, = of_type(
            self.templates["05-oracle-connectivity"],
            "Microsoft.Network/firewallPolicies/ruleCollectionGroups",
        )
        network_rule = rule["properties"]["ruleCollections"][0]["rules"][0]
        self.assertEqual(policy["sourceCidrs"], network_rule["sourceAddresses"][:7])
        self.assertIn(str(policy["destinationPort"]), network_rule["destinationPorts"])

    def test_oracle_dns_links_existing_provider_zone_to_cross_subscription_hub(self):
        template = self.templates["07-oracle-dns"]
        self.assertNotIn("defaultValue", template["parameters"]["oracleDnsZoneName"])
        self.assertGreater(template["parameters"]["oracleDnsZoneName"]["minLength"], 1)
        self.assertFalse(of_type(template, "Microsoft.Network/privateDnsZones"))
        self.assertFalse(of_type(template, "Microsoft.Network/dnsForwardingRulesets"))
        link, = of_type(template, "Microsoft.Network/privateDnsZones/virtualNetworkLinks")
        self.assertIn("parameters('oracleDnsZoneName')", link["name"])
        self.assertFalse(link["properties"]["registrationEnabled"])
        self.assertIn("aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483", link["properties"]["virtualNetwork"]["id"])
        self.assertIn("rg-workshop-hub", link["properties"]["virtualNetwork"]["id"])
        self.assertIn("oracleDnsZoneId", template["outputs"])


if __name__ == "__main__":
    unittest.main()
