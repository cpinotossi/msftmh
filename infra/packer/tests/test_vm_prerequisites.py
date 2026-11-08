import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from check_vm_prerequisites import azure_json, require_nvme_image, verify_capacity


class VmPrerequisitesTests(unittest.TestCase):
    def setUp(self):
        self.sku = {
            "name": "Standard_D2as_v7",
            "family": "standardDASv7Family",
            "restrictions": [{"type": "Zone", "restrictionInfo": {"zones": ["1"]}}],
            "locationInfo": [{"location": "FranceCentral", "zones": ["2"]}],
            "capabilities": [
                {"name": "CpuArchitectureType", "value": "x64"},
                {"name": "HyperVGenerations", "value": "V2"},
                {"name": "DiskControllerTypes", "value": "NVMe"},
                {"name": "vCPUs", "value": "2"},
            ],
        }
        self.usage = [
            {"name": {"value": "standardDASv7Family"}, "limit": "100", "currentValue": "0"},
            {"name": {"value": "cores"}, "limit": "100", "currentValue": "0"},
        ]

    def test_zone_one_block_does_not_block_zone_two(self):
        verify_capacity([self.sku], self.usage, "users")

    def test_selected_zone_block_is_fatal(self):
        self.sku["restrictions"][0]["restrictionInfo"]["zones"] = ["2"]
        with self.assertRaisesRegex(SystemExit, "restricted in zone 2"):
            verify_capacity([self.sku], self.usage, "users")

    def test_regional_block_is_fatal(self):
        self.sku["restrictions"] = [{"type": "Location"}]
        with self.assertRaisesRegex(SystemExit, "regionally restricted"):
            verify_capacity([self.sku], self.usage, "users")

    def test_unknown_or_incomplete_restriction_is_fatal(self):
        for restriction in ({"type": "Unexpected"}, {"type": "Zone"}):
            with self.subTest(restriction=restriction):
                self.sku["restrictions"] = [restriction]
                with self.assertRaises(SystemExit):
                    verify_capacity([self.sku], self.usage, "users")

    def test_zone_must_be_advertised(self):
        self.sku["locationInfo"][0]["zones"] = ["3"]
        with self.assertRaisesRegex(SystemExit, "advertise support for zone 2"):
            verify_capacity([self.sku], self.usage, "users")

    def test_all_seven_vms_need_family_and_regional_headroom(self):
        for index in (0, 1):
            usage = copy.deepcopy(self.usage)
            usage[index]["currentValue"] = "87"
            with self.subTest(quota=index), self.assertRaisesRegex(SystemExit, "14 vCPUs"):
                verify_capacity([self.sku], usage, "users")
        self.usage[0]["currentValue"] = "86"
        self.usage[1]["currentValue"] = "86"
        verify_capacity([self.sku], self.usage, "users")

    def test_regional_builder_does_not_invent_zone_setting(self):
        self.sku["name"] = "Standard_D4as_v7"
        self.sku["capabilities"][-1]["value"] = "4"
        self.usage[0]["limit"] = "4"
        self.usage[1]["limit"] = "4"
        verify_capacity([self.sku], self.usage, "build")

    def test_non_nvme_sku_is_fatal(self):
        self.sku["capabilities"][2]["value"] = "SCSI"
        with self.assertRaisesRegex(SystemExit, "NVMe controller"):
            verify_capacity([self.sku], self.usage, "users")

    def test_image_requires_nvme_metadata(self):
        image = {
            "architecture": "x64", "hyperVGeneration": "V2",
            "features": [{"name": "DiskControllerTypes", "value": "SCSI, NVMe"}],
        }
        require_nvme_image(image)
        image["features"] = []
        with self.assertRaisesRegex(SystemExit, "explicitly support NVMe"):
            require_nvme_image(image)

    def test_azure_failure_is_not_hidden(self):
        with patch("check_vm_prerequisites.subprocess.run") as run:
            run.return_value.returncode = 1
            run.return_value.stderr = "ERROR: AuthorizationFailed"
            with self.assertRaisesRegex(SystemExit, "AuthorizationFailed"):
                azure_json("vm", "list-skus")


if __name__ == "__main__":
    unittest.main()
