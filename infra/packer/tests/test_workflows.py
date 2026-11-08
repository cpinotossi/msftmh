"""Static contracts for the hosted-runner, new-tenant workshop workflows."""

from pathlib import Path
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[3]
WORKFLOWS = ROOT / ".github/workflows"
TENANT = "8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5"


class WorkflowTests(unittest.TestCase):
    def test_all_jobs_are_hosted_and_use_oidc(self):
        for path in WORKFLOWS.glob("*.yml"):
            with self.subTest(workflow=path.name):
                text = path.read_text()
                workflow = yaml.safe_load(text)
                self.assertNotIn("self-hosted", text)
                self.assertNotIn("az login --identity", text)
                self.assertNotIn("IMAGE_BUILD_RUNNER", text)
                self.assertNotIn("AZURE_AUTH_MODE", text)
                self.assertNotIn("TF_VAR_", text)
                self.assertEqual(workflow["permissions"]["contents"], "read")
                self.assertEqual(workflow["permissions"]["id-token"], "write")
                for job in workflow["jobs"].values():
                    if "uses" not in job:
                        self.assertEqual(job["runs-on"], "ubuntu-latest")
                    for step in job.get("steps", []):
                        if step.get("uses") == "azure/login@v2":
                            self.assertIn("tenant-id", step["with"])
                            self.assertIn("vars.AZURE_CLIENT_ID", text)
                if "azure/login@v2" in text:
                    self.assertIn(TENANT, text)

    def test_private_probes_remain_on_the_vm(self):
        text = (WORKFLOWS / "odaa-test-workshop.yml").read_text()
        self.assertIn("tests/base_database.py remote", text)
        self.assertIn("oci-cli==3.96.0", text)
        self.assertIn("environment: ${{ needs.phase-b-guard.outputs.participant_name }}", text)
        self.assertIn("python-version: '3.12'", text)
        self.assertIn("WORKSHOP_PHASE_B_READY", text)
        self.assertIn("if: always()", text)
        self.assertIn("Grant scoped topology Reader", text)
        self.assertIn("--assignee-object-id", text)
        self.assertIn("--role acdd72a7-3385-48ef-bd42-f606fba81ae7", text)
        self.assertIn("resourceGroups/$BASE_DB_VM_RG", text)
        self.assertIn("resourceGroups/$BASE_DB_RESOURCE_GROUP", text)

    def test_gallery_and_immutable_image_guard(self):
        gallery = (WORKFLOWS / "odaa-deploy-image-gallery.yml").read_text()
        self.assertIn("02-image-gallery.bicep", gallery)
        self.assertNotIn("4ce5b5cc-e869-451f-98fc-f50448849ee0", gallery)
        build = (WORKFLOWS / "odaa-build-image.yml").read_text()
        self.assertLess(build.index("Image version already exists"), build.index("Ensure Build Resource Group"))

    def test_diagnostic_is_required_and_cleanup_survives_probe_failure(self):
        workflow = yaml.safe_load((WORKFLOWS / "odaa-test-workshop.yml").read_text())
        steps = workflow["jobs"]["test-base-database"]["steps"]
        actions = {step.get("run"): step for step in steps if step.get("run", "").startswith("python3 tests/hub_dns_diagnostic.py")}
        self.assertEqual(set(actions), {
            "python3 tests/hub_dns_diagnostic.py create",
            "python3 tests/hub_dns_diagnostic.py probe",
            "python3 tests/hub_dns_diagnostic.py cleanup",
        })
        self.assertNotIn("continue-on-error", actions["python3 tests/hub_dns_diagnostic.py probe"])
        self.assertEqual(actions["python3 tests/hub_dns_diagnostic.py cleanup"]["if"], "always()")
        recovery = yaml.safe_load((WORKFLOWS / "odaa-cleanup-workshop.yml").read_text())
        cleanup = next(s for s in recovery["jobs"]["cleanup"]["steps"]
                       if s.get("run") == "python3 tests/hub_dns_diagnostic.py cleanup")
        self.assertEqual(cleanup["if"], "always() && inputs.diagnostic_owner != ''")


if __name__ == "__main__":
    unittest.main()
