"""Local mocks: python3 -m unittest discover -s tests -p 'test_*.py' -v."""

import contextlib
import io
import os
import re
import subprocess
import sys
import types
import unittest
from unittest.mock import MagicMock, mock_open, patch

import base_database as db
import provision_sql_user
import sql_probe

SUB = "4ce5b5cc-e869-451f-98fc-f50448849ee0"


def resource(kind, name, owned=True, anchor=None, owner="run-1"):
    value = {
        "id": f"/subscriptions/{SUB}/resourceGroups/rg-odaa-shared/providers/Oracle.Database/{kind}/{name}",
        "name": name, "properties": {},
        "tags": {**db.TAGS, "automation-owner": owner} if owned else {},
    }
    if anchor:
        value["properties"]["networkAnchorId"] = anchor
    return value


def tap():
    return "\n".join([f"1..{db.EXPECTED_TESTS}"] + [
        f"ok {n} " + ("SQL authenticates to the actual PDB and SELECT returns the expected value"
                       if n == db.EXPECTED_TESTS else f"test {n}") for n in range(1, db.EXPECTED_TESTS + 1)
    ]) + "\nBASE_DB_TEST_EXIT=0\n"


class MetadataTests(unittest.TestCase):
    def setUp(self):
        self.shape = {"properties": {
            "shapeName": "VM.BaseDB.x86", "shapeFamily": "VIRTUALMACHINE", "computeModel": "ECPU",
            "minimumNodeCount": 1, "maximumNodeCount": 1,
            "minimumCoreCount": 4, "availableCoreCount": 256, "coreCountIncrement": 4,
        }}
        self.version = {"properties": {"version": "26.0.0.0", "supportsPdb": True}}

    def check(self, **overrides):
        values = dict(subscription="sub", shape="VM.BaseDB.x86", version="26.0.0.0",
                      zone="1", compute_model="ECPU", compute=4, storage=256)
        values.update(overrides)
        with patch.object(db, "listing", side_effect=[[self.shape], [self.version]]) as listing:
            with contextlib.redirect_stdout(io.StringIO()):
                db.metadata(**values)
        return listing

    def test_exact_regional_filters_and_no_core_ecpu_conversion(self):
        listing = self.check()
        self.assertIn("/locations/francecentral/dbSystemShapes?zone=1", listing.call_args_list[0].args[0])
        query = listing.call_args_list[1].args[0]
        self.assertIn("shapeFamily=VIRTUALMACHINE", query)
        self.assertIn("storageManagement=LVM", query)
        self.assertNotIn("dbSystemShape=", query)

    def test_missing_or_unavailable_version_fails(self):
        for version in (None, "", "19.0.0.0"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                self.check(version=version)

    def test_missing_compute_model_metadata_fails(self):
        del self.shape["properties"]["computeModel"]
        with self.assertRaises(ValueError):
            self.check()

    def test_api_error_does_not_skip_preflight(self):
        with patch.object(db, "listing", side_effect=RuntimeError("unauthorized")), \
             self.assertRaises(RuntimeError):
            db.metadata("sub", "VM.BaseDB.x86", "26.0.0.0", "1", "ECPU", 4, 256)

    def test_small_storage_or_ecpu_count_fails(self):
        for values in ({"storage": 255}, {"compute": 3}, {"compute": 5}, {"compute": 257}):
            with self.subTest(values=values), self.assertRaises(ValueError):
                self.check(**values)

    def test_actual_ecpu_increment_and_required_bounds(self):
        self.check(compute=8)
        for key in ("minimumCoreCount", "availableCoreCount", "coreCountIncrement", "shapeFamily"):
            with self.subTest(key=key):
                original = self.shape["properties"].pop(key)
                try:
                    with self.assertRaises(ValueError):
                        self.check()
                finally:
                    self.shape["properties"][key] = original

    def test_old_shape_candidate_is_rejected_before_cloud_queries(self):
        with patch.object(db, "listing") as listing, self.assertRaises(ValueError):
            db.metadata("sub", "VM.Standard.x86", "26.0.0.0.0", "1", "ECPU", 4, 256)
        listing.assert_not_called()

    def test_no_pdb_or_preview_fails(self):
        for values in ({"supportsPdb": False}, {"supportsPdb": True, "isPreviewDbVersion": True}):
            self.version["properties"].update(values)
            with self.subTest(values=values), self.assertRaises(ValueError):
                self.check()

    def test_ocpu_bounds_applied_only_to_ocpu(self):
        self.shape["properties"].update(computeModel="OCPU", minimumCoreCount=1,
                                        availableCoreCount=8, coreCountIncrement=1)
        self.check(compute_model="OCPU", compute=1)
        with self.assertRaises(ValueError):
            self.check(compute_model="OCPU", compute=9)

    def test_two_node_only_shape_fails(self):
        self.shape["properties"]["minimumNodeCount"] = 2
        with self.assertRaises(ValueError):
            self.check()

    def test_missing_node_bounds_do_not_default_to_single_node(self):
        del self.shape["properties"]["minimumNodeCount"]
        with self.assertRaises(ValueError):
            self.check()


class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.anchor = resource("networkAnchors", "test")
        self.system = resource("dbSystems", "test", anchor=self.anchor["id"])

    def test_database_delete_verified_and_no_shared_anchor_access(self):
        events = []
        with patch.object(db, "listing", return_value=[self.system]) as listing, \
             patch.object(db, "rest", side_effect=lambda method, path: (
                 events.append((method, path)) or (self.system if path == self.system["id"] else self.anchor)
             )), patch.object(db, "wait_deleted", side_effect=lambda *a: events.append(("verified", a[0]))), \
             contextlib.redirect_stdout(io.StringIO()):
            db.cleanup(SUB, "run-1")
        self.assertEqual(events, [
            ("GET", self.system["id"]), ("DELETE", self.system["id"]),
            ("verified", self.system["id"]),
        ])
        self.assertEqual(listing.call_count, 1)
        self.assertTrue(listing.call_args.args[0].endswith("/dbSystems"))

    def test_live_unowned_database_preserves_owned_anchor(self):
        live = resource("dbSystems", "shared", owned=False, anchor=self.anchor["id"])
        with patch.object(db, "listing", side_effect=[[live], [self.anchor], [live]]), \
             patch.object(db, "rest") as rest, contextlib.redirect_stdout(io.StringIO()):
            db.cleanup(SUB, "run-1")
        rest.assert_not_called()

    def test_unowned_and_other_run_resources_not_deleted(self):
        other = resource("dbSystems", "other", owner="run-2", anchor=self.anchor["id"])
        unowned_anchor = resource("networkAnchors", "shared", owned=False)
        with patch.object(db, "listing", side_effect=[[other], [unowned_anchor], [other]]), \
             patch.object(db, "rest") as rest:
            db.cleanup(SUB, "run-1")
        rest.assert_not_called()

    def test_list_error_never_becomes_empty_success(self):
        with patch.object(db, "listing", side_effect=RuntimeError("API error")), \
             patch.object(db, "rest") as rest, self.assertRaises(RuntimeError):
            db.cleanup(SUB)
        rest.assert_not_called()

    def test_delete_error_stops_before_anchor_deletion(self):
        with patch.object(db, "listing", side_effect=[[self.system], [self.anchor]]), \
             patch.object(db, "rest", side_effect=[self.system, RuntimeError("delete failed")]) as rest, \
             self.assertRaises(RuntimeError), contextlib.redirect_stdout(io.StringIO()):
            db.cleanup(SUB)
        self.assertEqual(rest.call_count, 2)

    def test_unowned_database_without_anchor_reference_does_not_touch_shared_network(self):
        malformed = resource("dbSystems", "bad", owned=False)
        with patch.object(db, "listing", return_value=[malformed]), \
             patch.object(db, "rest") as rest:
            db.cleanup(SUB)
        rest.assert_not_called()

    def test_ownership_change_stops_database_deletion(self):
        with patch.object(db, "listing", side_effect=[[self.system], [self.anchor]]), \
             patch.object(db, "rest", return_value={}) as rest, self.assertRaises(ValueError):
            db.cleanup(SUB)
        self.assertEqual(rest.call_count, 1)

    def test_dry_run_never_calls_delete(self):
        with patch.object(db, "listing", side_effect=[[self.system], [self.anchor]]), \
             patch.object(db, "rest", side_effect=[self.system, self.anchor]) as rest, \
             contextlib.redirect_stdout(io.StringIO()):
            db.cleanup(SUB, dry_run=True)
        self.assertTrue(all(call.args[0] == "GET" for call in rest.call_args_list))

    def test_foreign_subscription_rejected_before_listing(self):
        with patch.object(db, "listing") as listing, self.assertRaises(ValueError):
            db.cleanup("other")
        listing.assert_not_called()


class RemoteTests(unittest.TestCase):
    def response(self, text=None):
        return {"properties": {
            "provisioningState": "Succeeded",
            "instanceView": {"executionState": "Succeeded", "exitCode": 0, "output": text or tap()},
        }}

    def test_actual_complete_tap_success(self):
        self.assertEqual(db.validate_remote(self.response()), tap())

    def test_bad_tap_and_remote_statuses_fail(self):
        malformed = [
            "", "all tests passed", tap().replace("1..13", "1..14"),
            tap().replace("ok 5 test 5", "not ok 5 test 5"),
            tap().replace("ok 5 test 5", "ok 5 test 5 # skip"),
            tap().replace("ok 5 test 5", "ok 5 test 5 # TODO"),
            tap().replace("ok 5 test 5\n", ""),
            tap().replace("ok 5 test 5", "ok 6 test 5"),
            tap().replace("BASE_DB_TEST_EXIT=0", "BASE_DB_TEST_EXIT=1"),
            tap().replace("BASE_DB_TEST_EXIT=0", ""),
            tap() + "BASE_DB_TEST_EXIT=0\n",
            tap().replace("SQL authenticates to the actual PDB", "TCP reachable"),
            tap() + "Bail out! error\n",
        ]
        for text in malformed:
            with self.subTest(text=text[-80:]), self.assertRaises(ValueError):
                response = self.response()
                response["properties"]["instanceView"]["output"] = text
                db.validate_remote(response)
        for response in ({}, {"properties": {"provisioningState": "Failed"}}):
            with self.subTest(response=response), self.assertRaises(ValueError):
                db.validate_remote(response)
        for field, value in (("executionState", "Failed"), ("exitCode", 1), ("exitCode", None), ("exitCode", "0")):
            response = self.response()
            response["properties"]["instanceView"][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                db.validate_remote(response)

    def test_test_plan_count_matches_actual_sources(self):
        actual = sum(len(re.findall(r"^@test ", p.read_text(), re.M)) for p in db.ROOT.glob("challenge-*.bats"))
        self.assertEqual(actual, db.EXPECTED_TESTS)

    def test_passwords_only_use_managed_protected_parameters(self):
        import json

        args = types.SimpleNamespace(dns_subscription="sub", vm_rg="rg", vm_name="vm", owner="run-1")
        response = self.response()
        response["properties"]["instanceView"]["error"] = "SYS_SECRET USER_SECRET"
        with patch.object(db.Path, "read_text", return_value='{"TEST_DB_HOST":"host"}'), \
             patch.dict(os.environ, BASE_DB_SYS_PASSWORD="SYS_SECRET", BASE_DB_TEST_PASSWORD="USER_SECRET"), \
             patch.object(db, "command", return_value="francecentral") as command, \
             patch.object(db, "rest", side_effect=[{}, response, {}]) as rest, \
             patch.object(db.Path, "write_text") as write, contextlib.redirect_stdout(io.StringIO()):
            db.remote(args)
        body = rest.call_args_list[0].args[2]
        self.assertIn("/runCommands/", rest.call_args_list[0].args[1])
        self.assertNotIn("parameters", body["properties"])
        self.assertEqual(body["properties"]["protectedParameters"], [
            {"name": "BASE_DB_SYS_PASSWORD", "value": "SYS_SECRET"},
            {"name": "BASE_DB_TEST_PASSWORD", "value": "USER_SECRET"},
        ])
        for secret in ("SYS_SECRET", "USER_SECRET"):
            self.assertNotIn(secret, body["properties"]["source"]["script"])
            self.assertNotIn(secret, str(command.call_args))
            self.assertNotIn(secret, write.call_args.args[0])
        self.assertEqual(rest.call_args_list[-1].args[0], "DELETE")
        report = json.loads(write.call_args.args[0])
        self.assertNotIn("protectedParameters", str(report))
        syntax = subprocess.run(["bash", "-n"], input=body["properties"]["source"]["script"], text=True, capture_output=True)
        self.assertEqual(syntax.returncode, 0, syntax.stderr)


class EndpointTests(unittest.TestCase):
    def test_service_is_parsed_not_guessed(self):
        expected = ("10.0.0.4", 1521, "workshop.example")
        self.assertEqual(db.parse_service("10.0.0.4:1521/workshop.example"), expected)
        self.assertEqual(db.parse_service(
            "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=10.0.0.4)(PORT=1521))"
            "(CONNECT_DATA=(SERVICE_NAME=workshop.example)))"), expected)

    def test_absent_ambiguous_or_tls_descriptors_fail(self):
        for value in (None, "", "workshop", "tcps://10.0.0.4:1522/pdb",
                      "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=10.0.0.4)(PORT=1522))(SERVICE_NAME=pdb))"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                db.parse_service(value)

    def test_multiple_candidates_fail(self):
        with self.assertRaises(ValueError):
            db.one([{}, {}], "DB node")

    def test_missing_node_private_ip_does_not_invent_address(self):
        args = types.SimpleNamespace(subscription=SUB, owner="run-1", dns_subscription="core",
                                     dns_rg="dns", vm_rg="vm")
        system = resource("dbSystems", "basetest01")
        system["properties"].update(ocid="ocid1.dbsystem.test", lifecycleState="Available",
                                    networkAnchorId="anchor")
        with patch.object(db, "wait_ready", return_value=system), \
             patch.object(db, "central_anchor", return_value=("anchor", "resource-anchor", {
                 "properties": {"ociSubnetId": "subnet"}
             })), \
             patch.dict(os.environ, OCI_COMPARTMENT_ID="compartment",
                        BASE_DB_RESOURCE_GROUP="rg-odaa-shared", BASE_DB_NAME="basetest01"), \
             patch.object(db, "oci", side_effect=[
                 [{"lifecycle-state": "AVAILABLE", "vnic-id": "vnic"}], {}
             ]), self.assertRaises(KeyError):
            db.discover(args)

    def test_endpoint_discovery_uses_node_and_actual_pdb_service(self):
        import json

        args = types.SimpleNamespace(
            subscription=SUB, owner="run-1", dns_subscription="core", dns_rg="dns", vm_rg="vm",
            shape="VM.BaseDB.x86", version="26.0.0.0", compute_model="ECPU", compute=4, storage=256,
        )
        system = resource("dbSystems", "basetest01")
        system["properties"].update(ocid="ocid1.dbsystem.test", lifecycleState="Available",
                                    listenerPort=1521, networkAnchorId="anchor")
        anchor = {"properties": {
            "ociSubnetId": "subnet", "ociVcnDnsLabel": "actualvcn",
            "cidrBlock": "192.168.0.0/24",
            "subnetId": "/subscriptions/sub/resourceGroups/central/providers/Microsoft.Network/virtualNetworks/oracle/subnets/delegated",
        }}
        responses = [
            [{"lifecycle-state": "AVAILABLE", "vnic-id": "vnic"}],
            {"private-ip": "10.0.0.4", "subnet-id": "subnet", "hostname-label": "node"},
            {"subnet-domain-name": "actualsubnet.actualvcn.example"},
            [{"id": "cdb"}],
            [{"id": "pdb", "pdb-name": "WORKSHOP", "lifecycle-state": "AVAILABLE"}],
            {"pdb-name": "WORKSHOP", "connection-strings": {"pdb-ip-default": "10.0.0.4:1521/actual.pdb.service"}},
        ]
        with patch.object(db, "wait_ready", return_value=system), \
             patch.object(db, "central_anchor", return_value=("anchor", "resource-anchor", anchor)), \
             patch.dict(os.environ, OCI_COMPARTMENT_ID="compartment",
                        BASE_DB_RESOURCE_GROUP="rg-odaa-shared", BASE_DB_NAME="basetest01",
                        BASE_DB_FIREWALL_PRIVATE_IP="10.20.0.4",
                        BASE_DB_DNS_RESOLVER_INBOUND_IP="10.20.1.4",
                        BASE_DB_HUB_VNET_ID="hub", BASE_DB_VM_VNET_NAME="runner",
                        BASE_DB_ORACLE_DNS_ZONE_ID="actual-zone-id",
                        BASE_DB_CENTRAL_DNS_ZONE_NAME="central.example"), \
             patch.object(db, "oci", side_effect=responses) as oci, \
             patch.object(db.Path, "write_text") as write, \
             patch.object(db, "listing", return_value=[]), patch.object(db, "rest") as rest:
            db.discover(args)
        config = json.loads(write.call_args.args[0])
        self.assertEqual(config["TEST_DB_SERVICE"], "actual.pdb.service")
        self.assertEqual(config["TEST_DB_IP"], "10.0.0.4")
        self.assertEqual(config["TEST_DB_VERSION"], args.version)
        self.assertIn("ocid1.dbsystem.test", oci.call_args_list[0].args)
        self.assertEqual(oci.call_args_list[3].args, (
            "db", "database", "list", "--compartment-id", "compartment",
            "--db-system-id", "ocid1.dbsystem.test",
        ))
        self.assertIn("pdb", oci.call_args_list[-1].args)
        self.assertEqual(config["TEST_DB_HOST"], "node.actualsubnet.actualvcn.example")
        self.assertEqual(config["TEST_ORACLE_DNS_ZONE_ID"], "actual-zone-id")
        self.assertNotIn("TEST_ORACLE_DNS_LISTENING_IP", config)
        self.assertNotIn("TEST_ORACLE_DNS_FORWARDING_IP", config)
        self.assertEqual(config["TEST_ODAA_DELEGATED_CIDR"], "192.168.0.0/24")
        self.assertEqual(config["TEST_ODAA_VNET"], "oracle")
        self.assertEqual(config["TEST_ODAA_SUBSCRIPTION_ID"], SUB)
        self.assertEqual(config["TEST_WORKSHOP_SUBSCRIPTION_ID"], "core")
        self.assertEqual(config["TEST_VM_RESOURCE_GROUP"], "vm")
        self.assertEqual(config["TEST_VM_VNET_NAME"], "runner")
        self.assertFalse(any(key.startswith(("TEST_MH", "TEST_TR_")) for key in config))
        rest.assert_not_called()


class CliTests(unittest.TestCase):
    def test_removed_terraform_fallback_cannot_select_a_subscription(self):
        environment = {"TF_VAR_mhodaa_subscription_id": "old-tenant-subscription"}
        with patch.dict(os.environ, environment, clear=True), \
             patch.object(sys, "argv", ["base_database.py", "cleanup"]), \
             patch.object(db, "cleanup") as cleanup, \
             contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            db.main()
        self.assertEqual(error.exception.code, 2)
        cleanup.assert_not_called()

    def test_canonical_subscription_environment_keeps_cleanup_explicit(self):
        with patch.dict(os.environ, {"ODAA_SUBSCRIPTION_ID": "current"}, clear=True), \
             patch.object(sys, "argv", ["base_database.py", "cleanup"]), \
             patch.object(db, "cleanup") as cleanup:
            db.main()
        cleanup.assert_called_once_with("current", None, False)

    def test_error_output_never_contains_password(self):
        result = subprocess.CompletedProcess(["az"], 1, "PASSWORD", "PASSWORD")
        with patch.object(db.subprocess, "run", return_value=result), self.assertRaises(RuntimeError) as error:
            db.command(["az", "deployment"])
        self.assertNotIn("PASSWORD", str(error.exception))

    def test_pagination_requires_value_array(self):
        with patch.object(db, "rest", return_value={}), self.assertRaises(RuntimeError):
            db.listing("/test")

    def test_pagination_collects_all_pages(self):
        with patch.object(db, "rest", side_effect=[
            {"value": [1], "nextLink": "https://management.azure.com/next?api-version=2025-09-01"},
            {"value": [2]},
        ]):
            self.assertEqual(db.listing("/test"), [1, 2])

    def test_pagination_refuses_external_hosts(self):
        with self.assertRaises(ValueError):
            db.rest("GET", "https://attacker.example/resources")

    def test_workflow_inputs_and_secrets_not_shell_interpolated(self):
        for path in (db.ROOT.parent / ".github/workflows").glob("odaa-*-workshop.yml"):
            if path.name not in ("odaa-test-workshop.yml", "odaa-cleanup-workshop.yml"):
                continue
            text = path.read_text()
            self.assertNotRegex(text, r"(?:password|Password)='\$\{\{")
            self.assertNotIn("/tmp", text)
            self.assertNotIn("cleanup-oci-networking", text)
            self.assertNotIn("autonomous-database", text)

    def test_template_dependency_and_secure_password(self):
        import json

        result = subprocess.run(
            ["az", "bicep", "build", "--file", str(db.ROOT / "bicep/base-db-test.bicep"), "--stdout"],
            capture_output=True, text=True, timeout=120, check=True,
        )
        template = json.loads(result.stdout)
        self.assertEqual(template["parameters"]["adminPassword"]["type"], "securestring")
        system, = template["resources"]
        self.assertEqual(system["type"], "Oracle.Database/dbSystems")
        self.assertEqual(template["parameters"]["dbSystemName"]["allowedValues"],
                         [f"basetest{index:02}" for index in range(1, 8)]
                         + [f"basedb{index}" for index in range(1, 8)])
        self.assertEqual(system["name"], "[parameters('dbSystemName')]")
        self.assertEqual(system["properties"]["hostname"], "[parameters('dbSystemName')]")
        self.assertNotIn("dependsOn", system)
        self.assertEqual(system["properties"]["networkAnchorId"], "[parameters('networkAnchorId')]")
        self.assertEqual(system["properties"]["resourceAnchorId"], "[parameters('resourceAnchorId')]")
        self.assertEqual(system["properties"]["nodeCount"], 1)
        self.assertEqual(system["properties"]["databaseEdition"], "EnterpriseEdition")
        self.assertEqual(system["properties"]["licenseModel"], "LicenseIncluded")
        self.assertIn("adminPassword", system["properties"]["adminPassword"])


class SqlTests(unittest.TestCase):
    def test_bootstrap_limited_user_only_inside_intended_pdb(self):
        cursor = MagicMock()
        cursor.fetchone.return_value = ("WORKSHOP", 1)
        connection = MagicMock()
        connection.cursor.return_value.__enter__.return_value = cursor
        driver = types.SimpleNamespace(
            ConnectParams=MagicMock(), connect=MagicMock(), init_oracle_client=MagicMock(),
        )
        driver.connect.return_value.__enter__.return_value = connection
        env = {
            "TEST_DB_HOST": "test.host", "TEST_DB_PORT": "1521", "TEST_DB_SERVICE": "actual.service",
            "TEST_DB_PDB": "WORKSHOP", "BASE_DB_SYS_PASSWORD": "Privileged_123",
            "BASE_DB_TEST_PASSWORD": "Limited_123",
        }
        with patch.dict(sys.modules, oracledb=driver), patch.dict(os.environ, env), \
             patch.object(provision_sql_user.os, "makedirs"), \
             patch.object(provision_sql_user.os, "open", return_value=123) as opened, \
             patch.object(provision_sql_user.os, "fdopen", mock_open()):
            provision_sql_user.provision()
            driver.init_oracle_client.assert_called_once_with()
            self.assertEqual(driver.connect.call_args.kwargs["user"], "SYSTEM")
            self.assertEqual(cursor.execute.call_args_list[1].args[0], 'CREATE USER WORKSHOP IDENTIFIED BY "Limited_123"')
            self.assertEqual(cursor.execute.call_args_list[2].args[0], "GRANT CREATE SESSION TO WORKSHOP")
            self.assertEqual(opened.call_args.args[-1], 0o600)
            cursor.execute.reset_mock()
            cursor.fetchone.return_value = ("CDB$ROOT", 1)
            with self.assertRaises(ValueError):
                provision_sql_user.provision()
            self.assertEqual(cursor.execute.call_count, 1)

    def test_real_select_and_wrong_container_rejection(self):
        cursor = MagicMock()
        cursor.fetchone.return_value = ("WORKSHOP", 1)
        connection = MagicMock()
        connection.cursor.return_value.__enter__.return_value = cursor
        driver = types.SimpleNamespace(
            ConnectParams=MagicMock(), connect=MagicMock(), init_oracle_client=MagicMock(),
        )
        driver.connect.return_value.__enter__.return_value = connection
        info = types.SimpleNamespace(st_mode=0o100600, st_uid=0)
        env = {
            "TEST_DB_HOST": "basetest00.basedb.workshop.internal",
            "TEST_DB_PORT": "1521", "TEST_DB_SERVICE": "workshop.domain", "TEST_DB_PDB": "WORKSHOP",
        }
        with patch.dict(sys.modules, oracledb=driver), patch.dict(os.environ, env), \
             patch.object(sql_probe.os, "open", return_value=123), \
             patch.object(sql_probe.os, "fdopen", mock_open(read_data='{"username":"SYSTEM","password":"SECRET"}')), \
             patch.object(sql_probe.os, "fstat", return_value=info):
            sql_probe.probe()
            driver.init_oracle_client.assert_called_once_with()
            cursor.execute.assert_called_once_with("SELECT sys_context('USERENV', 'CON_NAME'), 1 FROM dual")
            with patch.object(sql_probe, "measure_latency", return_value={"samples": 10}) as measured:
                self.assertEqual(sql_probe.probe(measure=True), {"samples": 10})
                measured.assert_called_once_with(cursor)
            cursor.fetchone.return_value = ("CDB$ROOT", 1)
            with patch.object(sql_probe, "measure_latency") as measured, self.assertRaises(ValueError):
                sql_probe.probe(measure=True)
            measured.assert_not_called()
            info.st_mode = 0o100644
            with self.assertRaises(ValueError):
                sql_probe.probe()

    def test_native_client_initialization_failure_never_falls_back_to_unencrypted_thin_mode(self):
        driver = types.SimpleNamespace(
            ConnectParams=MagicMock(), connect=MagicMock(),
            init_oracle_client=MagicMock(side_effect=RuntimeError("Native client unavailable")),
        )
        env = {
            "BASE_DB_TEST_PASSWORD": "Limited_123", "BASE_DB_SYS_PASSWORD": "Privileged_123",
        }
        with patch.dict(sys.modules, oracledb=driver), patch.dict(os.environ, env), \
             self.assertRaisesRegex(RuntimeError, "Native client unavailable"):
            provision_sql_user.provision()
        driver.connect.assert_not_called()


if __name__ == "__main__":
    unittest.main()
