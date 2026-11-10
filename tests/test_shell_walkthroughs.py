"""Verify small participant shell/SQL commands and the separate latency probe."""

import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest.mock import MagicMock, patch

import sql_probe


ROOT = Path(__file__).resolve().parents[1]
SQL_GUIDE = ROOT / "walkthrough/perf-test-odaa-basedb/perf-test-odaa-basedb.md"
DNS_GUIDE = ROOT / "walkthrough/verify-odaa-basedb-dns/verify-odaa-basedb-dns.md"
CONNECT_GUIDE = ROOT / "walkthrough/connect-odaa-basedb/connect-odaa-basedb.md"
SECURITY_GUIDE = ROOT / "walkthrough/configure-odaa-basedb-nsg/configure-odaa-basedb-nsg.md"


class ShellWalkthroughTests(unittest.TestCase):
    def blocks(self, path, language="bash"):
        return [match[1] for match in re.findall(
            rf"^([ \t]*)```{language}\n(.*?)^\1```[ \t]*$", path.read_text(), re.S | re.M,
        )]

    def command_blocks(self, path, command):
        return [block for block in self.blocks(path) if block.startswith(command)]

    def test_all_guides_have_a_visible_user2_warning(self):
        guides = sorted((ROOT / "walkthrough").glob("*/*.md"))
        self.assertEqual(len(guides), 7)
        for path in guides:
            source = path.read_text()
            with self.subTest(path=path):
                self.assertIn("> [!WARNING]\n> **User2 is only an example.**", source)
                self.assertIn("your own assigned user", source)
                self.assertLess(source.index("> [!WARNING]"), source.index("## Step") if "## Step" in source else 1000)
                prose = "\n".join(line for line in source.splitlines() if not line.startswith("|"))
                self.assertNotRegex(prose, r"(?i)\b(?:user1|mhuser1|vm-mhuser1|rg-vm-mhuser1|basedb1)\b")

    def test_participant_guides_use_portal_bastion_without_local_cli(self):
        for path in (ROOT / "walkthrough").glob("*/*.md"):
            source = path.read_text()
            with self.subTest(path=path):
                self.assertNotIn("az network bastion ssh", source)
                self.assertNotIn("resolvectl", source)
                self.assertNotIn("nslookup", source)
                self.assertNotIn("USER_NUMBER=", source)
                for block in self.blocks(path):
                    self.assertNotRegex(block, r"(?m)^\s*(?:az|ssh)\s")
        for path in [
            ROOT / "walkthrough/setup-user-account/setup-user-account.md",
            DNS_GUIDE, CONNECT_GUIDE, SQL_GUIDE,
        ]:
            with self.subTest(path=path):
                self.assertIn("Connect via Bastion", path.read_text())
                self.assertIn("Microsoft Entra ID", path.read_text())

    def test_all_copyable_shell_blocks_parse_without_embedded_python(self):
        for path in (ROOT / "walkthrough").glob("*/*.md"):
            for block in self.blocks(path):
                with self.subTest(path=path, block=block):
                    self.assertNotRegex(block, r"\bpython[23]?\b")
                    self.assertNotRegex(block, r"(?m)^\s*read\s")
                    subprocess.run(["bash", "-n"], input=block, text=True, check=True, capture_output=True)

    def run_with_tool(self, tool, block, arguments, status=0, input_text=""):
        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / tool
            executable.write_text(
                "#!/bin/bash\nprintf '%s\\n' \"$@\"\n"
                f"exit {status}\n"
            )
            executable.chmod(0o700)
            result = subprocess.run(
                ["bash", "-c", block], input=input_text, text=True, capture_output=True,
                env={**os.environ, "PATH": f"{directory}:{os.environ['PATH']}",
                     "DB_HOST": "node.example", "DB_SERVICE": "WORKSHOP.example",
                     "DB_IP": "192.168.0.193",
                     "DB_CONNECT": "node.example:1521/WORKSHOP.example"},
            )
            self.assertEqual(result.returncode, status)
            self.assertEqual(result.stdout.splitlines(), arguments)
            return result

    def test_latency_tools_connect_without_a_password_argument(self):
        assignment, = self.command_blocks(SQL_GUIDE, 'DB_CONNECT=')
        for tool in ["ociping", "connping"]:
            block, = self.command_blocks(SQL_GUIDE, tool + " -l")
            arguments = [
                "-l", "SYSTEM@//node.example:1521/WORKSHOP.example",
                "--period=60", "--interval=1",
            ]
            with self.subTest(tool=tool):
                self.run_with_tool(tool, block, arguments)
                self.run_with_tool(tool, block, arguments, status=1)
                self.assertNotIn("password", block.lower())
                self.run_with_tool(
                    tool, "\n".join([assignment, block]),
                    ["-l", "SYSTEM@//basedb2.ocisnetodaadel.ocivnetodaasha.oraclevcn.com:1521/"
                     "WORKSHOP.ocisnetodaadel.ocivnetodaasha.oraclevcn.com",
                     "--period=60", "--interval=1"],
                )

    def test_latency_challenge_uses_only_ociping_and_connping_measurements(self):
        source = SQL_GUIDE.read_text()
        self.assertEqual(self.blocks(SQL_GUIDE, "sql"), [])
        for retired in ["sqlplus", "SET TIMING", "adbping"]:
            self.assertNotIn(retired, source)
        for tool in ["ociping", "connping"]:
            self.assertEqual(len(self.command_blocks(SQL_GUIDE, tool + " --help")), 1)
        self.assertIn("not a separate command", source)

    def test_dns_check_uses_dig_with_a_bounded_wait(self):
        quick, = self.command_blocks(DNS_GUIDE, "dig ")
        self.run_with_tool("dig", quick, [
            "node.example", "A", "+short", "+time=5", "+tries=1",
        ])

    def test_latency_examples_match_the_participant_results(self):
        source = SQL_GUIDE.read_text()
        for result in [
            "1.182 6.7",
            "ociping (ms) mean=1.199, stddev=0.160, min=1.110, max=1.992",
            "connect:50.85 ms, ociping:1.179 ms, dualping:1.276 ms, sid=52, inst#=1, time=8.8",
            "connect:66.65 ms, ociping:2.280 ms, dualping:2.305 ms, sid=52, inst#=1, time=9.8",
            "connect mean=58.75, stddev=7.90, min=50.85, max=66.65",
            "ociping mean=1.73, stddev=0.55, min=1.18, max=2.28",
            "dualping mean=1.79, stddev=0.51, min=1.28, max=2.31",
        ]:
            with self.subTest(result=result):
                self.assertIn(result, source)
        self.assertIn("**milliseconds**", source)
        self.assertIn("**seconds**", source)
        self.assertIn("Two samples are not enough", source)
        self.assertIn("Do not paste `ociping mean=...`", source)
        self.assertIn("ociping.html", source)
        self.assertIn("connping.html", source)

    def test_connect_guide_uses_the_copied_easy_connect_string(self):
        block, = self.command_blocks(CONNECT_GUIDE, "sqlplus -L")
        arguments = ["-L", "SYSTEM@//node.example:1521/WORKSHOP.example"]
        self.run_with_tool("sqlplus", block, arguments)
        self.run_with_tool("sqlplus", block, arguments, status=1)
        assignment, = self.command_blocks(CONNECT_GUIDE, 'DB_CONNECT=')
        self.run_with_tool(
            "sqlplus", "\n".join([assignment, block]),
            ["-L", "SYSTEM@//basedb2.ocisnetodaadel.ocivnetodaasha.oraclevcn.com:1521/"
             "WORKSHOP.ocisnetodaadel.ocivnetodaasha.oraclevcn.com"],
        )
        self.assertNotIn("password", block.lower())
        self.assertEqual([x.strip() for x in self.blocks(CONNECT_GUIDE, "sql")], [
            "SHOW USER", "SHOW CON_NAME", "SELECT 1 AS result FROM dual;", "EXIT",
        ])

    def test_initial_dns_check_uses_the_fqdn_assigned_on_the_vm(self):
        assignment, = self.command_blocks(DNS_GUIDE, "DB_HOST=")
        quick = self.command_blocks(DNS_GUIDE, "dig ")[0]
        self.run_with_tool(
            "dig", "\n".join([assignment, quick]),
            ["basedb2.ocisnetodaadel.ocivnetodaasha.oraclevcn.com",
             "A", "+short", "+time=5", "+tries=1"],
        )

    def test_dns_connection_and_security_are_separate_challenges(self):
        self.assertNotIn("nsg", str(DNS_GUIDE).lower())
        self.assertNotRegex(DNS_GUIDE.read_text(), r"(?im)^#{1,6} .*nsg")
        self.assertEqual(self.command_blocks(DNS_GUIDE, "sqlplus"), [])
        self.assertIn("## Challenge 3:", SECURITY_GUIDE.read_text())
        self.assertIn("## Challenge 4:", DNS_GUIDE.read_text())
        self.assertIn("## Challenge 5:", CONNECT_GUIDE.read_text())
        self.assertIn("## Challenge 6:", SQL_GUIDE.read_text())
        self.assertIn("Add only your own TCP `1521` rule.", SECURITY_GUIDE.read_text())
        self.assertIn("Select **Add Rules** to save.", SECURITY_GUIDE.read_text())
        self.assertIn("Leave unchecked (stateful)", SECURITY_GUIDE.read_text())
        self.assertIn("`10.0.2.0/24`", SECURITY_GUIDE.read_text())
        self.assertEqual(self.blocks(SECURITY_GUIDE), [])

    def test_challenge_navigation_follows_database_security_dns_connect_sql(self):
        chain = [
            ROOT / "walkthrough/create-odaa-basedb/create-odaa-basedb.md",
            SECURITY_GUIDE, DNS_GUIDE, CONNECT_GUIDE, SQL_GUIDE,
        ]
        for current, following in zip(chain, chain[1:]):
            with self.subTest(path=current):
                self.assertRegex(
                    current.read_text(),
                    rf"Next: \[[^\]]+\]\(\.\./{re.escape(following.parent.name)}/{re.escape(following.name)}\)",
                )
        overview = (ROOT / "README.md").read_text()
        headings = re.findall(r"^### Challenge (\d+):", overview, re.M)
        self.assertEqual(headings, [str(number) for number in range(7)])
        self.assertLess(overview.index("### Challenge 3:"), overview.index("### Challenge 4:"))

    def test_security_guide_finds_the_vm_subnet_before_adding_ingress(self):
        source = SECURITY_GUIDE.read_text()
        find_subnet = source.index("## Step 3: Find your VM subnet CIDR in Azure")
        open_oci = source.index("## Step 4: Open the database's OCI security group")
        add_rule = source.index("## Step 5: Add your OCI NSG ingress rule")
        self.assertLess(find_subnet, open_oci)
        self.assertLess(open_oci, add_rule)
        for text in [
            "Networking > Network settings", "Virtual network / subnet",
            "Settings > Subnets", "snet-vm-mhuser2", "IPv4 address range",
            "paste the subnet address", "Source port range", "Destination port range",
        ]:
            with self.subTest(text=text):
                self.assertIn(text, source)

    def test_organizer_latency_excludes_warmup_and_reports_ten_samples(self):
        cursor = MagicMock()
        cursor.fetchone.return_value = (1,)
        times = [0, 0.1]
        for milliseconds in range(1, 11):
            times.extend([1, 1 + milliseconds / 1000])
        with patch.object(sql_probe.time, "perf_counter", side_effect=times):
            metrics = sql_probe.measure_latency(cursor)
        self.assertEqual(metrics["samples"], 10)
        self.assertEqual(metrics["unit"], "ms")
        self.assertAlmostEqual(metrics["min"], 1)
        self.assertAlmostEqual(metrics["median"], 5.5)
        self.assertAlmostEqual(metrics["max"], 10)
        self.assertEqual(cursor.execute.call_count, 11)
        self.assertTrue(all(call.args == ("SELECT 1 FROM dual",) for call in cursor.execute.call_args_list))

    def test_organizer_latency_rejects_an_unexpected_sql_value(self):
        cursor = MagicMock()
        cursor.fetchone.return_value = (0,)
        with self.assertRaisesRegex(ValueError, "Unexpected SQL value"):
            sql_probe.measure_latency(cursor)
        self.assertEqual(cursor.execute.call_count, 1)


if __name__ == "__main__":
    unittest.main()
