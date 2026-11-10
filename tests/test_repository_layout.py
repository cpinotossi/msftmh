"""Protect the Bicep/Packer source boundary and private legacy-file exclusions."""

from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]


class RepositoryLayoutTests(unittest.TestCase):
    def ignored(self, paths):
        result = subprocess.run(
            ["git", "check-ignore", "--no-index", "--stdin"], cwd=ROOT,
            input="\n".join(paths) + "\n", text=True, capture_output=True, check=False,
        )
        self.assertIn(result.returncode, (0, 1), result.stderr)
        return set(result.stdout.splitlines())

    def test_legacy_state_variables_and_credentials_remain_ignored(self):
        paths = {
            "infra/users/terraform.tfvars", "infra/shared/terraform.tfvars.json",
            "infra/github-runner/terraform.tfstate", "infra/github-runner/terraform.tfstate.backup",
            "infra/identity/.terraform/providers/example", "infra/identity/.terraform.lock.hcl",
            "infra/.oci/config", "infra/.oci/example.pem",
            "infra/packer/variables.auto.pkrvars.hcl", "infra/packer/packer-manifest.json",
            "infra/identity/user_credentials.json", ".copilot-tracking/research/example.md",
        }
        self.assertEqual(self.ignored(paths), paths)
        self.assertFalse((ROOT / "infra/.gitignore").exists())

    def test_active_bicep_packer_and_walkthrough_inputs_are_not_ignored(self):
        paths = {
            "infra/packer/oracle-workshop.pkr.hcl", "infra/packer/variables.pkrvars.hcl.example",
            "infra/deployments/03-users.bicepparam", "infra/deployments/modules/spoke-access.bicep",
            "tests/workshop_config.json", "infra/deployments/oracle-subscription.bicep",
            "walkthrough/setup-user-account/setup-user-account.md",
        }
        for path in paths:
            self.assertTrue((ROOT / path).is_file(), path)
        self.assertEqual(self.ignored(paths), set())

    def test_local_credentials_remain_ignored_if_copied_into_checkout(self):
        paths = {
            ".workshop-secrets/basetest01/sys-password",
            ".workshop-secrets/basetest01/test-password",
            ".workshop-secrets/basetest01/base-db-config.json",
            "walkthrough/.workshop-secrets/basedb1/id_rsa",
            "walkthrough/local/sys-password", "walkthrough/local/test-password",
        }
        self.assertEqual(self.ignored(paths), paths)
        tracked = subprocess.run(
            ["git", "ls-files", "--", ":(glob)**/.workshop-secrets/**",
             ":(glob)**/sys-password", ":(glob)**/test-password"],
            cwd=ROOT, capture_output=True, text=True, check=True,
        )
        self.assertEqual(tracked.stdout, "", "Local credentials must never be tracked")

    def test_source_tree_uses_markdown_instead_of_notebooks(self):
        result = subprocess.run(
            ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
            cwd=ROOT, capture_output=True, text=True, check=True,
        )
        for name in set(result.stdout.split("\0")) - {""}:
            if (ROOT / name).is_file():
                self.assertFalse(name.endswith(".ipynb"), name)
        self.assertFalse((ROOT / "walkthrough/workshop.py").exists())
        self.assertFalse((ROOT / "walkthrough/notebook-requirements.txt").exists())

    def test_existing_versioned_sources_contain_no_retired_terraform_or_exercises(self):
        result = subprocess.run(
            ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
            cwd=ROOT, capture_output=True, text=True, check=True,
        )
        for name in set(result.stdout.split("\0")) - {""}:
            if not (ROOT / name).is_file():
                continue
            with self.subTest(path=name):
                self.assertFalse(name.endswith((".tf", ".tf.json", ".tfvars", ".tfvars.json")))
                self.assertNotEqual(Path(name).name, ".terraform.lock.hcl")
                self.assertNotIn(".tfstate", Path(name).name)
                self.assertFalse(name.startswith((".copilot-tracking/", "walkthrough/onprem-ramp-up/")))

    def test_active_workflows_do_not_install_or_run_terraform(self):
        for path in (ROOT / ".github/workflows").glob("*.yml"):
            with self.subTest(workflow=path.name):
                source = path.read_text().lower()
                self.assertNotIn("setup-terraform", source)
                self.assertNotRegex(source, r"(?m)^\s*(?:-\s*run:\s*)?terraform\s")
                self.assertNotIn("terraform_remote_state", source)


if __name__ == "__main__":
    unittest.main()
