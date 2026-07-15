import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "setup-agents.py"


def load_module():
    spec = importlib.util.spec_from_file_location("scc", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class ParseArgsTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()

    def test_defaults(self):
        a = self.scc.parse_args(["--config", "/tmp/x.json"])
        self.assertEqual(a.config, "/tmp/x.json")
        self.assertEqual(a.agent, [])
        self.assertEqual(a.group, [])
        self.assertEqual(a.only_group, [])
        self.assertEqual(a.no_group, [])
        self.assertFalse(a.all_groups)
        self.assertFalse(a.no_default_groups)
        self.assertFalse(a.no_plugins)
        self.assertFalse(a.enable_plugins)
        self.assertFalse(a.no_permissions)
        self.assertFalse(a.no_mcp)
        self.assertFalse(a.dry_run)

    def test_repeatable_group_flags(self):
        a = self.scc.parse_args(
            ["--config", "/tmp/x.json", "--group", "a", "--group", "b", "--no-group", "c"]
        )
        self.assertEqual(a.group, ["a", "b"])
        self.assertEqual(a.no_group, ["c"])

    def test_repeatable_agent_flag(self):
        a = self.scc.parse_args(
            ["--config", "/tmp/x.json", "--agent", "claude", "--agent", "codex"]
        )
        self.assertEqual(a.agent, ["claude", "codex"])

    def test_agent_rejects_unknown(self):
        with self.assertRaises(SystemExit):
            self.scc.parse_args(["--config", "/tmp/x.json", "--agent", "gemini"])

    def test_toggles(self):
        a = self.scc.parse_args(
            ["--config", "/tmp/x.json", "--no-plugins", "--dry-run"]
        )
        self.assertTrue(a.no_plugins)
        self.assertTrue(a.dry_run)


if __name__ == "__main__":
    unittest.main()
