"""Offline checks for the fixed workshop image toolchain."""

from pathlib import Path
import re
import os
import subprocess
import tempfile
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[3]
PACKER = ROOT / "infra/packer"


class ImageConfigTests(unittest.TestCase):
    def setUp(self):
        self.play = yaml.safe_load((PACKER / "ansible/oracle-tools.yml").read_text())[0]
        self.tasks = self.play["tasks"]

    def test_downloads_are_fixed_and_checksummed(self):
        task = next(t for t in self.tasks if "ansible.builtin.get_url" in t)
        self.assertEqual(len(task["loop"]), 9)
        for download in task["loop"]:
            self.assertRegex(download["sha256"], r"^[a-f0-9]{64}$")
            self.assertTrue(download["url"].startswith("https://"))
            self.assertNotIn("latest", download["url"])
        self.assertEqual(task["ansible.builtin.get_url"]["checksum"], "sha256:{{ item.sha256 }}")

    def test_runtime_verification_is_required(self):
        task = next(t for t in self.tasks if t["name"].startswith("Verify required"))
        self.assertNotIn("ignore_errors", task)
        for tool in ("sqlplus", "/sql ", "rwloadsim", "connping", "az ", "oci ", "oracledb", "bats", "dig"):
            self.assertTrue(any(tool in command for command in task["loop"]), tool)
        text = (PACKER / "ansible/oracle-tools.yml").read_text().lower()
        self.assertNotIn("ignore_errors:", text)
        self.assertNotIn("wallet_dir", text)
        self.assertNotIn("adbping", text)
        self.assertIn("basedbuserXX.basedb.workshop.internal", (PACKER / "ansible/oracle-tools.yml").read_text())

    def test_paths_match_verified_archive_layout(self):
        task = next(t for t in self.tasks if t["name"].startswith("Extract rwloadsim"))
        self.assertNotIn("extra_opts", task["ansible.builtin.unarchive"])
        task = next(t for t in self.tasks if t["name"].startswith("Link the exact"))
        self.assertEqual(task["ansible.builtin.file"]["src"], "/opt/oracle/instantclient_23_26")
        self.assertFalse(any(t.get("ansible.builtin.file", {}).get("path") == "/opt/oracle/instantclient" for t in self.tasks))

    def test_remote_playbook_reuses_canonical_toolchain(self):
        remote = yaml.safe_load((ROOT / "infra/ansible/playbooks/oracle-tools.yml").read_text())
        self.assertEqual(remote[0]["ansible.builtin.import_playbook"], "../../packer/ansible/oracle-tools.yml")

    def test_local_defaults_and_gen2_source(self):
        config = (PACKER / "variables.auto.pkrvars.hcl").read_text()
        for value in ("aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483", "rg-workshop-images", "1.1.0"):
            self.assertIn(value, config)
        source = (PACKER / "oracle-workshop.pkr.hcl").read_text()
        for key, value in (("image_offer", "ubuntu-24_04-lts"), ("image_sku", "server"), ("image_version", "24.04.202610250")):
            self.assertRegex(source, rf'{key}\s*=\s*"{re.escape(value)}"')
        self.assertIn("use_azure_cli_auth = true", source)
        self.assertNotIn("AADSSHLoginForLinux", source)
        self.assertRegex(config, r'vm_size\s*=\s*"Standard_D4as_v7"')
        self.assertIn('disk_controller_type = "NVMe"', source)
        self.assertIn('version = "= 2.6.5"', source)

    def test_nvme_boot_preparation(self):
        packages = next(t["ansible.builtin.apt"]["name"] for t in self.tasks if t["name"].startswith("Install Ubuntu"))
        for package in ("linux-azure", "initramfs-tools", "nvme-cli"):
            self.assertIn(package, packages)
        modules = next(t for t in self.tasks if t["name"].startswith("Include NVMe"))
        self.assertEqual(modules["loop"], ["nvme", "nvme_core"])
        text = (PACKER / "ansible/oracle-tools.yml").read_text()
        self.assertIn("io_timeout=240", text)
        self.assertIn("update-initramfs -u -k all", text)
        self.assertIn("update-grub", text)
        source = (PACKER / "oracle-workshop.pkr.hcl").read_text()
        self.assertLess(source.index("sudo reboot"), source.index("scripts/verify-nvme.sh"))
        self.assertLess(source.index("scripts/verify-nvme.sh"), source.index('"/usr/sbin/waagent -force'))
        subprocess.run(["bash", "-n", str(PACKER / "scripts/verify-nvme.sh")], check=True)

    def test_fstab_must_use_persistent_devices(self):
        task = next(t for t in self.tasks if t["name"].startswith("Reject enumerated"))
        for device, expected in (
            ("UUID=abc", 0), ("LABEL=cloudimg-rootfs", 0),
            ("/dev/disk/by-uuid/abc", 0), ("/dev/disk/cloud/azure_root-part1", 0),
            ("/dev/sda1", 1), ("/dev/nvme0n1p1", 1),
        ):
            with self.subTest(device=device), tempfile.TemporaryDirectory() as directory:
                fstab = Path(directory) / "fstab"
                fstab.write_text(f"{device} / ext4 defaults 0 1\n")
                script = task["ansible.builtin.shell"].replace("/etc/fstab", str(fstab))
                result = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                if expected:
                    self.assertIn("Use UUID", result.stdout)

    def test_root_probe_does_not_require_dev_block_aliases(self):
        script = (PACKER / "scripts/verify-nvme.sh").read_text()
        root_probe = script.split('timeout="$(cat /sys/module/')[0]
        for device, expected in (("/dev/nvme0n1p1", 0), ("/dev/sda1", 1)):
            with self.subTest(device=device), tempfile.TemporaryDirectory() as directory:
                commands = {
                    "uname": "printf 'x86_64\\n'",
                    "findmnt": "case \"$*\" in *--raw*) printf '259:1\\n';; *) printf '259:1  \\n';; esac",
                    "lsblk": f"printf '{device} 259:1\\n'",
                }
                for name, command in commands.items():
                    executable = Path(directory) / name
                    executable.write_text("#!/bin/sh\n" + command + "\n")
                    executable.chmod(0o755)
                environment = dict(os.environ, PATH=directory + os.pathsep + os.environ["PATH"])
                result = subprocess.run(["sh", "-c", root_probe], env=environment, capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stderr)
                if expected:
                    self.assertIn("Expected an NVMe root disk", result.stderr)

    def test_shell_and_workflow_bodies_parse(self):
        subprocess.run(["bash", "-n", str(PACKER / "scripts/install-oracle-tools.sh")], check=True)
        workflow = yaml.safe_load((ROOT / ".github/workflows/odaa-build-image.yml").read_text())
        self.assertEqual(workflow["env"]["IMAGE_RESOURCE_GROUP"], "rg-workshop-images")
        self.assertIn("ubuntu-latest", workflow["jobs"]["build"]["runs-on"])
        for step in workflow["jobs"]["build"]["steps"]:
            if "run" in step:
                subprocess.run(["bash", "-n"], input=step["run"], text=True, check=True)
        for task in self.tasks:
            content = task.get("ansible.builtin.copy", {}).get("content", "")
            if content.startswith("#!/bin/sh") or task["name"].startswith("Configure login"):
                subprocess.run(["bash", "-n"], input=content, text=True, check=True)


if __name__ == "__main__":
    unittest.main()
