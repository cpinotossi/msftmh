"""Focused offline mocks for the organizer-owned central network contract."""

import contextlib
import io
import json
import os
import types
import unittest
from unittest.mock import mock_open, patch

import base_database as db
import export_shared_config as shared
import network_probe as network

SUB = "4ce5b5cc-e869-451f-98fc-f50448849ee0"
PROVIDER = f"/subscriptions/{SUB}/resourceGroups/rg-odaa-shared/providers/Oracle.Database"
ANCHOR = PROVIDER + "/networkAnchors/nw-anchor-workshop"
RESOURCE = PROVIDER + "/resourceAnchors/anchor-odaa-shared"
HUB = "/subscriptions/workshop/resourceGroups/hub/providers/Microsoft.Network/virtualNetworks/hub"
ENV = {
    "BASE_DB_NETWORK_ANCHOR_IDS_BY_ZONE": json.dumps({"1": ANCHOR}),
    "BASE_DB_RESOURCE_ANCHOR_ID": RESOURCE,
    "TEST_MHCORE_SUB": "workshop", "TEST_TR_RG": "runner", "TEST_TR_VNET": "runner",
    "TEST_HUB_VNET_ID": HUB, "TEST_FIREWALL_PRIVATE_IP": "10.20.0.4",
    "TEST_HUB_RESOLVER_INBOUND_IP": "10.20.1.4",
    "TEST_ODAA_DELEGATED_CIDR": "192.168.0.0/24",
    "TEST_ORACLE_DNS_LISTENING_IP": "192.168.0.6",
    "TEST_DB_HOST": "node.actualsubnet.actualvcn.example", "TEST_DB_IP": "192.168.0.10",
    "TEST_CENTRAL_DNS_ZONE_NAME": "workshop.internal",
}


def anchor():
    return {
        "zones": ["1"], "tags": {"managed-by": "Terraform"},
        "properties": {
            "provisioningState": "Succeeded", "resourceAnchorId": RESOURCE,
            "isOracleDnsListeningEndpointEnabled": True, "isOracleDnsForwardingEndpointEnabled": True,
            "dnsListeningEndpointIpAddress": "192.168.0.6", "dnsForwardingEndpointIpAddress": "192.168.0.7",
            "ociVcnDnsLabel": "actualvcn", "ociSubnetId": "ocid1.subnet.actual",
            "subnetId": "/subscriptions/odaa/resourceGroups/central/providers/Microsoft.Network/virtualNetworks/oracle/subnets/delegated",
            "cidrBlock": "192.168.0.0/24",
        },
    }


class CentralAnchorTests(unittest.TestCase):
    def check(self, value=None, **env):
        with patch.dict(os.environ, {**ENV, **env}), patch.object(db, "rest", side_effect=[
            value or anchor(), {"properties": {"provisioningState": "Succeeded"}},
        ]) as rest:
            result = db.central_anchor(types.SimpleNamespace(subscription=SUB, zone="1"))
        self.assertTrue(all(call.args[0] == "GET" for call in rest.call_args_list))
        return result

    def test_selects_existing_zonal_anchor_and_reads_actual_endpoint(self):
        self.assertEqual(self.check()[2]["properties"]["dnsListeningEndpointIpAddress"], "192.168.0.6")

    def test_missing_zone_does_not_choose_default_anchor(self):
        with self.assertRaises(KeyError):
            self.check(BASE_DB_NETWORK_ANCHOR_IDS_BY_ZONE=json.dumps({"2": ANCHOR}))

    def test_wrong_subscription_rejected_before_arm_request(self):
        with self.assertRaises(ValueError), patch.object(db, "rest") as rest:
            self.check(BASE_DB_RESOURCE_ANCHOR_ID=RESOURCE.replace(SUB, "other"))
        rest.assert_not_called()

    def test_dns_endpoints_label_cidr_zone_and_management_are_required(self):
        mutations = [
            ("properties", "isOracleDnsListeningEndpointEnabled", False),
            ("properties", "isOracleDnsForwardingEndpointEnabled", False),
            ("properties", "dnsListeningEndpointIpAddress", ""),
            ("properties", "dnsForwardingEndpointIpAddress", "8.8.8.8"),
            ("properties", "ociVcnDnsLabel", ""),
            ("properties", "ociSubnetId", ""),
            ("properties", "cidrBlock", "192.168.0.0/16"),
            ("properties", "resourceAnchorId", RESOURCE + "-other"),
        ]
        for section, key, value in mutations:
            resource = anchor()
            resource[section][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.check(resource)
        resource = anchor()
        resource["zones"] = ["2"]
        with self.assertRaises(ValueError):
            self.check(resource)

    def test_db_only_cleanup_never_enumerates_even_owned_legacy_anchors(self):
        system = {"id": f"/subscriptions/{SUB}/resourceGroups/rg-odaa-mhuser1/providers/Oracle.Database/dbSystems/test",
                  "tags": {**db.TAGS, "automation-owner": "run"}}
        with patch.object(db, "listing", return_value=[system]) as listing, \
             patch.object(db, "rest", return_value=system) as rest, \
             patch.object(db, "wait_deleted"), contextlib.redirect_stdout(io.StringIO()):
            db.cleanup(SUB, "run")
        self.assertEqual(listing.call_count, 1)
        self.assertTrue(listing.call_args.args[0].endswith("/dbSystems"))
        self.assertEqual([call.args[0] for call in rest.call_args_list], ["GET", "DELETE"])
        self.assertTrue(all("/dbSystems/" in call.args[1] for call in rest.call_args_list))

    def test_create_deploys_only_isolated_db_with_cross_rg_anchor_ids(self):
        args = types.SimpleNamespace(subscription=SUB, zone="1", owner="run",
                                     shape="VM.Standard.x86", version="26.0.0.0",
                                     compute_model="ECPU", compute=4, storage=256)
        with patch.dict(os.environ, BASE_DB_SYS_PASSWORD="Secret_#12ABcd",
                        BASE_DB_SSH_PUBLIC_KEY="ssh-rsa public-test-key",
                        BASE_DB_RESOURCE_GROUP="rg-odaa-mhuser1"), \
             patch.object(db, "metadata"), \
             patch.object(db, "central_anchor", return_value=(ANCHOR, RESOURCE, anchor())), \
             patch.object(db, "listing", return_value=[]), \
             patch.object(db.os, "open", return_value=123), \
             patch.object(db.os, "fdopen", mock_open()), \
             patch.object(db.json, "dump") as dump, \
             patch.object(db.Path, "unlink"), \
             patch.object(db, "command") as command, \
             patch.object(db, "rest") as rest, \
             patch.object(db, "wait_ready") as wait:
            db.create(args)
        parameters = dump.call_args.args[0]["parameters"]
        self.assertEqual(parameters["networkAnchorId"]["value"], ANCHOR)
        self.assertEqual(parameters["resourceAnchorId"]["value"], RESOURCE)
        argv = command.call_args.args[0]
        self.assertEqual(argv[argv.index("--resource-group") + 1], "rg-odaa-mhuser1")
        self.assertNotIn("Secret_#12ABcd", argv)
        self.assertEqual(wait.call_count, 1)
        self.assertIn("/resourceGroups/rg-odaa-mhuser1/providers/Oracle.Database/dbSystems/", wait.call_args.args[0])
        rest.assert_not_called()

    def test_cleanup_preserves_tagged_databases_outside_static_participant_groups(self):
        systems = [{"id": f"/subscriptions/{SUB}/resourceGroups/{group}/providers/Oracle.Database/dbSystems/test",
                    "tags": db.TAGS} for group in ("rg-odaa-shared", "rg-odaa-user00", "rg-odaa-mhuser8")]
        with patch.object(db, "listing", return_value=systems), patch.object(db, "rest") as rest:
            db.cleanup(SUB)
        rest.assert_not_called()


class SharedConfigTests(unittest.TestCase):
    def deployments(self):
        outputs = {key: {"type": "String", "value": "value"} for key in shared.OUTPUTS}
        outputs["networkAnchorId"]["value"] = ANCHOR
        outputs["networkAnchorZone"]["value"] = "1"
        return [{"properties": {"provisioningState": "Succeeded", "outputs": outputs}}] + [
            {"properties": {"provisioningState": "Succeeded", "outputs": {}}} for _ in range(3)
        ]

    def test_only_whitelisted_non_secret_outputs_exported(self):
        deployments = self.deployments()
        deployments[0]["properties"]["outputs"]["user_credentials"] = {"type": "SecureString", "value": "SECRET"}
        stream = io.StringIO()
        shared.export(deployments, stream)
        self.assertNotIn("SECRET", stream.getvalue())
        self.assertIn("BASE_DB_NETWORK_ANCHOR_IDS_BY_ZONE=" + json.dumps({"1": ANCHOR}, separators=(",", ":")),
                      stream.getvalue())

    def test_missing_sensitive_or_multiline_output_fails_before_any_export(self):
        for value in ({"type": "SecureString", "value": "secret"}, {"type": "String", "value": "unsafe\nname=secret"}):
            bad = self.deployments()
            bad[0]["properties"]["outputs"]["centralDnsZoneName"] = value
            stream = io.StringIO()
            with self.assertRaises(ValueError):
                shared.export(bad, stream)
            self.assertEqual(stream.getvalue(), "")

    def test_all_canonical_deployments_must_exist_and_succeed(self):
        for state in ("Running", "Failed", "Canceled", None):
            deployments = self.deployments()
            deployments[3]["properties"]["provisioningState"] = state
            with self.subTest(state=state), self.assertRaises(ValueError):
                shared.export(deployments, io.StringIO())
        with self.assertRaises(ValueError):
            shared.export(self.deployments()[:3], io.StringIO())
        deployments = self.deployments()
        del deployments[0]["properties"]["outputs"]["ociVcnId"]
        with self.assertRaises(KeyError):
            shared.export(deployments, io.StringIO())

    def test_static_seven_vm_and_database_scopes_no_scaling(self):
        for key, number in zip(("01", "02", "03", "04", "05", "06", "07"), range(1, 8)):
            config, user = shared.participant(key)
            self.assertEqual(len(config["participants"]), 7)
            self.assertEqual(user, {
                "name": f"mhuser{number}", "vmResourceGroup": f"rg-vm-mhuser{number}",
                "vmName": f"vm-mhuser{number}", "databaseResourceGroup": f"rg-odaa-mhuser{number}",
            })
        for key in ("00", "08", "user00"):
            with self.assertRaises(KeyError):
                shared.participant(key)

    def test_cli_only_gets_valid_deployments_and_exports_guarded_outputs(self):
        ids = [f"/subscriptions/{SUB}/providers/Microsoft.Resources/deployments/stage-{number}"
               for number in (2, 4, 6, 7)]
        argv = ["export_shared_config.py"]
        for resource_id in ids:
            argv.extend(["--deployment-id", resource_id])
        response = types.SimpleNamespace(returncode=0, stdout=json.dumps(self.deployments()[0]))
        with patch.object(shared.sys, "argv", argv), patch.dict(os.environ, {}, clear=True), \
             patch.object(shared.subprocess, "run", return_value=response) as run, \
             contextlib.redirect_stdout(io.StringIO()) as stdout:
            shared.main()
        self.assertEqual(run.call_count, 4)
        for call in run.call_args_list:
            self.assertEqual(call.args[0][0:4], ["az", "rest", "--method", "GET"])
        self.assertIn("BASE_DB_NETWORK_ANCHOR_IDS_BY_ZONE=", stdout.getvalue())

    def test_cli_rejects_missing_duplicate_or_foreign_deployment_ids_before_reads(self):
        valid = f"/subscriptions/{SUB}/providers/Microsoft.Resources/deployments/stage"
        for ids in ([valid], [valid] * 4, [
            valid, valid + "2", valid + "3",
            "/subscriptions/foreign/providers/Microsoft.Resources/deployments/stage",
        ]):
            argv = ["export_shared_config.py"]
            for resource_id in ids:
                argv.extend(["--deployment-id", resource_id])
            with patch.object(shared.sys, "argv", argv), \
                 patch.object(shared.subprocess, "run") as run, self.assertRaises(ValueError):
                shared.main()
            run.assert_not_called()

    def test_workflow_contract_has_single_workshop_subscription_and_no_legacy_reset(self):
        for name in ("odaa-test-workshop.yml", "odaa-cleanup-workshop.yml"):
            text = (db.ROOT.parent / ".github/workflows" / name).read_text()
            self.assertIn("WORKSHOP_SUBSCRIPTION_ID: aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483", text)
            self.assertNotIn("TF_VAR_", text)
            self.assertNotIn("self-hosted", text)
            self.assertIn("azure/login@v2", text)
            self.assertIn("8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5", text)
            self.assertNotIn("user_credentials.template.json", text)
            self.assertNotIn("user_count=0", text)
            self.assertNotIn("cleanup-dns", text)
        test_workflow = (db.ROOT.parent / ".github/workflows/odaa-test-workshop.yml").read_text()
        self.assertIn("WORKSHOP_PHASE_B_READY", test_workflow)
        self.assertIn("needs: phase-b-guard", test_workflow)
        self.assertIn("options: ['01', '02', '03', '04', '05', '06', '07']", test_workflow)
        self.assertIn("WORKSHOP_ORACLE_DNS_DEPLOYMENT_ID", test_workflow)
        self.assertNotIn("setup-terraform", test_workflow)
        self.assertNotIn("terraform -chdir", test_workflow)
        self.assertIn("export_shared_config.py", test_workflow)


class NetworkTests(unittest.TestCase):
    def setUp(self):
        self.vnet = {"properties": {
            "dhcpOptions": {"dnsServers": [ENV["TEST_FIREWALL_PRIVATE_IP"]]},
            "virtualNetworkPeerings": [{"properties": {
                "remoteVirtualNetwork": {"id": HUB}, "peeringState": "Connected", "allowForwardedTraffic": True,
            }}],
            "subnets": [{"properties": {"routeTable": {"id": "route"}}}],
        }}
        self.table = {"properties": {"routes": [{"properties": {
            "addressPrefix": prefix, "nextHopType": "VirtualAppliance",
            "nextHopIpAddress": ENV["TEST_FIREWALL_PRIVATE_IP"],
        }} for prefix in ("0.0.0.0/0", "192.168.0.0/24")]}}
        self.firewalls = [{"ipConfigurations": [{"privateIPAddress": ENV["TEST_FIREWALL_PRIVATE_IP"]}],
                           "dnsSettings": {"enableProxy": True, "servers": [ENV["TEST_HUB_RESOLVER_INBOUND_IP"]]}}]
        self.rulesets = {"value": [{"id": "ruleset"}]}
        self.links = {"value": [{"properties": {
            "virtualNetwork": {"id": HUB}, "provisioningState": "Succeeded",
        }}]}
        self.rules = {"value": [{"properties": {
            "domainName": "actualvcn.example.", "forwardingRuleState": "Enabled",
            "targetDnsServers": [{"ipAddress": ENV["TEST_ORACLE_DNS_LISTENING_IP"], "port": 53}],
        }}]}

    def topology(self):
        with patch.dict(os.environ, ENV), patch.object(network, "arm", side_effect=[
            self.vnet, self.table, self.rulesets, self.links, self.rules,
        ]), \
             patch.object(network, "command", return_value=json.dumps(self.firewalls)):
            network.topology()

    def test_hub_only_routes_custom_dns_and_firewall_proxy(self):
        self.topology()

    def test_old_direct_peering_broad_udr_or_wrong_dns_fails(self):
        changes = [
            lambda: self.vnet["properties"]["dhcpOptions"].update(dnsServers=["168.63.129.16"]),
            lambda: self.vnet["properties"]["virtualNetworkPeerings"][0]["properties"]["remoteVirtualNetwork"].update(id="oracle"),
            lambda: self.table["properties"]["routes"][1]["properties"].update(addressPrefix="192.168.0.0/16"),
            lambda: self.firewalls[0]["dnsSettings"].update(servers=["192.168.0.6"]),
            lambda: self.rules["value"][0]["properties"].update(forwardingRuleState="Disabled"),
            lambda: self.rules["value"][0]["properties"].update(targetDnsServers=[{"ipAddress": "192.168.0.99", "port": 53}]),
        ]
        for change in changes:
            self.setUp()
            change()
            with self.assertRaises(ValueError):
                self.topology()

    def test_dns_udp_tcp_forward_and_reverse_required(self):
        calls = []
        def query(server, host, kind="A", tcp=False):
            calls.append((server, host, kind, tcp))
            return [ENV["TEST_DB_IP"]] if kind == "A" else ["authoritative SOA"]
        with patch.dict(os.environ, ENV), patch.object(network, "query", side_effect=query):
            network.endpoint_dns()
        self.assertEqual(len(calls), 8)
        self.assertIn((ENV["TEST_ORACLE_DNS_LISTENING_IP"], ENV["TEST_CENTRAL_DNS_ZONE_NAME"], "SOA", True), calls)
        self.assertNotIn(ENV["TEST_FIREWALL_PRIVATE_IP"], [call[0] for call in calls])

    def test_participant_dns_never_queries_resolver_or_oracle_directly(self):
        with patch.dict(os.environ, ENV), patch.object(network, "query", return_value=[ENV["TEST_DB_IP"]]) as query:
            network.dns()
        self.assertEqual([call.args for call in query.call_args_list], [
            (ENV["TEST_FIREWALL_PRIVATE_IP"], ENV["TEST_DB_HOST"]),
            (ENV["TEST_FIREWALL_PRIVATE_IP"], ENV["TEST_DB_HOST"]),
        ])
        self.assertEqual([call.kwargs["tcp"] for call in query.call_args_list], [False, True])

    def test_azure_only_smoke_compares_firewall_and_resolver_udp_and_tcp(self):
        with patch.dict(os.environ, ENV), patch.object(network, "query", return_value=["SOA"]) as query:
            network.hub_dns()
        self.assertEqual(query.call_count, 4)
        self.assertNotIn(ENV["TEST_ORACLE_DNS_LISTENING_IP"], [call.args[0] for call in query.call_args_list])

    def test_missing_or_wrong_dns_answer_fails_not_skips(self):
        for answer in ([], ["192.168.0.11"]):
            with patch.dict(os.environ, ENV), patch.object(network, "query", return_value=answer), \
                 self.assertRaises(ValueError):
                network.dns()

    def test_reverse_dns_mismatch_fails(self):
        with patch.dict(os.environ, ENV), patch.object(network, "query", side_effect=[
            *([[ENV["TEST_DB_IP"]]] * 4), ["hub SOA"], ["wrong SOA"],
        ]), self.assertRaises(ValueError):
            network.endpoint_dns()
