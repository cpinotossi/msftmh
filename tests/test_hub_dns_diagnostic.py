import contextlib
import io
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import hub_dns_diagnostic as diagnostic

OWNER = "123456789-1"
GROUP = f"rg-workshop-dns-{OWNER}"


def owned_group():
    return {
        "id": f"/subscriptions/{diagnostic.SUBSCRIPTION}/resourceGroups/{GROUP}",
        "tags": {**diagnostic.TAGS, "automation-owner": OWNER},
    }


class DiagnosticTests(unittest.TestCase):
    def test_invalid_owner_cannot_select_arbitrary_resource_groups(self):
        for owner in ("", "rg-workshop-hub", "../hub", "123-1/other"):
            with patch.dict(os.environ, BASE_DB_OWNER=owner), self.assertRaises(ValueError):
                diagnostic.scope()

    def test_cleanup_absent_group_is_explicit_and_never_deletes(self):
        with patch.dict(os.environ, BASE_DB_OWNER=OWNER), \
             patch.object(diagnostic, "exists", return_value=False), \
             patch.object(diagnostic.db, "command") as command, \
             contextlib.redirect_stdout(io.StringIO()) as output:
            diagnostic.cleanup()
        command.assert_not_called()
        self.assertIn("No diagnostic resource group remains", output.getvalue())

    def test_cleanup_refuses_changed_ownership_or_scope(self):
        for group in ({}, {**owned_group(), "tags": {}},
                      {**owned_group(), "id": "/subscriptions/other/resourceGroups/hub"}):
            with patch.dict(os.environ, BASE_DB_OWNER=OWNER), \
                 patch.object(diagnostic, "exists", return_value=True), \
                 patch.object(diagnostic.db, "command", return_value=group) as command, \
                 self.assertRaises(ValueError):
                diagnostic.cleanup()
            self.assertEqual(command.call_count, 1)

    def test_cleanup_deletes_only_exact_owned_group_and_verifies_absence(self):
        with patch.dict(os.environ, BASE_DB_OWNER=OWNER), \
             patch.object(diagnostic, "exists", side_effect=[True, False]) as exists, \
             patch.object(diagnostic.db, "command", return_value=owned_group()) as command, \
             contextlib.redirect_stdout(io.StringIO()):
            diagnostic.cleanup()
        self.assertEqual(exists.call_count, 2)
        self.assertEqual(command.call_args.args[0], [
            "az", "group", "delete", "--subscription", diagnostic.SUBSCRIPTION,
            "--name", GROUP, "--yes",
        ])

    def test_create_never_adopts_existing_group(self):
        with patch.dict(os.environ, BASE_DB_OWNER=OWNER), \
             patch.object(diagnostic, "exists", return_value=True), \
             patch.object(diagnostic.db, "command") as command, self.assertRaises(ValueError):
            diagnostic.create()
        command.assert_not_called()

    def test_smoke_exports_no_oracle_endpoint_and_requires_its_distinct_marker(self):
        with patch.dict(os.environ, BASE_DB_OWNER=OWNER), \
             patch.object(diagnostic, "require_owned"), \
             patch.object(diagnostic.db, "execute_run_command", return_value="HUB_DNS_OK") as execute, \
             contextlib.redirect_stdout(io.StringIO()):
            diagnostic.probe(smoke=True)
        script = execute.call_args.args[2]
        self.assertIn("--hub-dns", script)
        self.assertNotIn("TEST_ORACLE_DNS_LISTENING_IP", script.split("base64 -d")[1])
        self.assertEqual(execute.call_args.args[3], {})

    def test_probe_requires_canonical_hub_before_guest_execution(self):
        with patch.dict(os.environ, BASE_DB_OWNER=OWNER), \
             patch.object(diagnostic, "require_owned"), \
             patch.object(Path, "read_text", return_value=json.dumps({"TEST_HUB_VNET_ID": "other"})), \
             patch.object(diagnostic.db, "execute_run_command") as execute, self.assertRaises(ValueError):
            diagnostic.probe()
        execute.assert_not_called()

    def test_missing_nonzero_or_duplicate_guest_success_marker_fails(self):
        def response(output="BIDIRECTIONAL_DNS_OK", exit_code=0):
            return {"properties": {"provisioningState": "Succeeded", "instanceView": {
                "executionState": "Succeeded", "exitCode": exit_code, "output": output,
            }}}
        for value in ({}, response(""), response(exit_code=1), response(exit_code="0"),
                      response("BIDIRECTIONAL_DNS_OK\nBIDIRECTIONAL_DNS_OK")):
            with self.assertRaises(ValueError):
                diagnostic.validate(value, "BIDIRECTIONAL_DNS_OK")
        self.assertEqual(diagnostic.validate(response(), "BIDIRECTIONAL_DNS_OK"), "BIDIRECTIONAL_DNS_OK")
