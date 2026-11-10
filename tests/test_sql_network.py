"""Fail-closed, additive configuration of the actual BaseDB node's OCI NSG."""

import contextlib
from copy import deepcopy
import io
import json
import os
import types
import unittest
from unittest.mock import patch

import base_database as db


SUB = "4ce5b5cc-e869-451f-98fc-f50448849ee0"
PROVIDER = f"/subscriptions/{SUB}/resourceGroups/rg-odaa-shared/providers/Oracle.Database"
ANCHOR = PROVIDER + "/networkAnchors/nw-anchor-workshop"
SYSTEM = PROVIDER + "/dbSystems/basetest01"


def actual_rule(desired):
    return {
        "direction": desired["direction"], "protocol": desired["protocol"],
        "source-type": desired["sourceType"], "source": desired["source"],
        "is-stateless": desired["isStateless"], "is-valid": True,
        "tcp-options": {"destination-port-range": desired["tcpOptions"]["destinationPortRange"]},
        "description": desired["description"],
    }


class SqlNetworkTests(unittest.TestCase):
    def setUp(self):
        self.config = db.workshop_config()
        self.desired = db.sql_ingress_rules(self.config)
        self.args = types.SimpleNamespace(subscription=SUB, zone="1", owner="run", dry_run=False)
        self.system = {
            "tags": {**db.TAGS, "automation-owner": "run"},
            "properties": {
                "provisioningState": "Succeeded", "lifecycleState": "Available",
                "networkAnchorId": ANCHOR, "listenerPort": 1521, "ocid": "db-system",
            },
        }
        self.anchor = {"properties": {"ociSubnetId": "subnet", "ociVcnId": "vcn"}}
        self.vnets = [{"properties": {"addressSpace": {"addressPrefixes": [rule["source"]]}}}
                      for rule in self.desired]
        self.node = [{"lifecycle-state": "AVAILABLE", "vnic-id": "vnic"}]
        self.vnic = {"subnet-id": "subnet", "nsg-ids": ["nsg"]}
        self.nsg = {"vcn-id": "vcn", "compartment-id": "compartment", "lifecycle-state": "AVAILABLE"}
        self.provider_rule = {"description": None, "direction": "EGRESS", "protocol": "all"}
        self.before = [self.provider_rule]
        self.after = [self.provider_rule, *(actual_rule(rule) for rule in self.desired)]

    def run_configure(self):
        rule_lists = 0

        def oci(*args):
            nonlocal rule_lists
            if args[:3] == ("db", "node", "list"):
                return self.node
            if args[:3] == ("network", "vnic", "get"):
                return self.vnic
            if args[:3] == ("network", "nsg", "get"):
                return self.nsg
            if args[:4] == ("network", "nsg", "rules", "list"):
                rule_lists += 1
                return self.before if rule_lists == 1 else self.after
            if args[:4] == ("network", "nsg", "rules", "add"):
                return {}
            raise AssertionError(f"Unexpected OCI operation: {args}")

        self.oci = None
        with patch.dict(os.environ, BASE_DB_RESOURCE_GROUP="rg-odaa-shared", BASE_DB_NAME="basetest01",
                        OCI_COMPARTMENT_ID="compartment"), \
             patch.object(db, "workshop_config", return_value=self.config), \
             patch.object(db, "central_anchor", return_value=(ANCHOR, "resource", self.anchor)), \
             patch.object(db, "rest", side_effect=[self.system, *self.vnets]) as rest, \
             patch.object(db, "oci", side_effect=oci) as mocked_oci, \
             patch.object(db.time, "sleep"), contextlib.redirect_stdout(io.StringIO()) as output:
            self.oci = mocked_oci
            db.configure_network(self.args)
        self.assertTrue(all(call.args[0] == "GET" for call in rest.call_args_list))
        return output.getvalue()

    def additions(self):
        return [call for call in self.oci.call_args_list
                if call.args[:4] == ("network", "nsg", "rules", "add")]

    def test_adds_only_seven_stateful_tcp1521_rules_to_attached_nsg(self):
        self.assertIn("added 7", self.run_configure())
        addition, = self.additions()
        self.assertEqual(addition.args[4:6], ("--nsg-id", "nsg"))
        self.assertEqual(json.loads(addition.args[-1]), self.desired)
        self.assertFalse(any(call.args[3:4] in (("remove",), ("update",))
                             for call in self.oci.call_args_list))

    def test_repeated_application_is_idempotent(self):
        self.before = self.after
        self.assertIn("added 0", self.run_configure())
        self.assertEqual(self.additions(), [])

    def test_adds_only_missing_rules(self):
        self.before += [actual_rule(self.desired[0])]
        self.run_configure()
        self.assertEqual(json.loads(self.additions()[0].args[-1]), self.desired[1:])

    def test_dry_run_does_not_mutate(self):
        self.args.dry_run = True
        self.assertEqual(json.loads(self.run_configure())["missingRules"], self.desired)
        self.assertEqual(self.additions(), [])

    def test_wrong_owner_anchor_availability_or_port_cannot_mutate(self):
        for field, value in (("networkAnchorId", "other"), ("listenerPort", 22),
                             ("provisioningState", "Updating"), ("lifecycleState", "Failed")):
            self.setUp()
            self.system["properties"][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.run_configure()
            self.oci.assert_not_called()
        self.setUp()
        self.system["tags"]["automation-owner"] = "other"
        with self.assertRaises(ValueError):
            self.run_configure()
        self.oci.assert_not_called()

    def test_source_mismatch_fails_before_oci_access(self):
        self.vnets[0]["properties"]["addressSpace"]["addressPrefixes"] = ["10.1.0.0/16"]
        with self.assertRaises(ValueError):
            self.run_configure()
        self.oci.assert_not_called()

    def test_foreign_subnet_vcn_compartment_or_ambiguous_nsg_cannot_mutate(self):
        for target, key, value in (("vnic", "subnet-id", "foreign"),
                                   ("vnic", "nsg-ids", ["one", "two"]),
                                   ("nsg", "vcn-id", "foreign"),
                                   ("nsg", "compartment-id", "foreign"),
                                   ("nsg", "lifecycle-state", "TERMINATING")):
            self.setUp()
            getattr(self, target)[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.run_configure()
            self.assertEqual(self.additions(), [])

    def test_drifted_managed_rule_is_not_overwritten(self):
        stale = actual_rule(self.desired[0])
        stale["source"] = "0.0.0.0/0"
        self.before.append(stale)
        with self.assertRaisesRegex(ValueError, "drifted"):
            self.run_configure()
        self.assertEqual(self.additions(), [])

    def test_missing_post_update_rules_fail_explicitly(self):
        self.after = self.before
        with self.assertRaisesRegex(RuntimeError, "not verified"):
            self.run_configure()
        self.assertEqual(len(self.additions()), 1)

    def test_broad_sources_or_wrong_port_are_rejected(self):
        for key, value in (("sourceCidrs", ["0.0.0.0/0"]),
                           ("destinationPort", 22), ("destinationPort", "1521")):
            config = deepcopy(self.config)
            config["oracleSqlIngress"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                db.sql_ingress_rules(config)

    def test_non_equivalent_rule_is_not_accepted(self):
        for change in (
            {"is-stateless": True}, {"is-valid": False}, {"protocol": "all"},
            {"tcp-options": None},
            {"tcp-options": {"destination-port-range": {"min": 1, "max": 65535}}},
            {"tcp-options": {"destination-port-range": {"min": 1521, "max": 1521},
                             "source-port-range": {"min": 1234, "max": 1234}}},
        ):
            actual = actual_rule(self.desired[0])
            actual.update(change)
            with self.subTest(change=change):
                self.assertFalse(db.matches_sql_rule(actual, self.desired[0]))

    def test_workflow_configures_ingress_after_discovery_before_probes(self):
        text = (db.ROOT.parent / ".github/workflows/odaa-test-workshop.yml").read_text()
        self.assertLess(text.index("base_database.py discover"), text.index("base_database.py configure-network"))
        self.assertLess(text.index("base_database.py configure-network"), text.index("base_database.py remote"))


if __name__ == "__main__":
    unittest.main()
