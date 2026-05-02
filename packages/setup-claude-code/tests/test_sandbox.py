import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "setup-claude-code.py"


def load_module():
    spec = importlib.util.spec_from_file_location("scc", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class MergeSandboxTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()
        self.desired = {
            "filesystem": {
                "allowWrite": ["~/.cache/**"],
                "denyWrite":  ["/mnt/t4/**"],
            },
        }

    def test_writes_enabled_true(self):
        out = self.scc.merge_sandbox_into({}, self.desired)
        self.assertTrue(out["sandbox"]["enabled"])

    def test_union_filesystem_lists(self):
        settings = {"sandbox": {"filesystem": {"allowWrite": ["~/Workspaces/**"]}}}
        out = self.scc.merge_sandbox_into(settings, self.desired)
        self.assertEqual(
            out["sandbox"]["filesystem"]["allowWrite"],
            ["~/Workspaces/**", "~/.cache/**"],
        )
        self.assertEqual(out["sandbox"]["filesystem"]["denyWrite"], ["/mnt/t4/**"])

    def test_preserves_unrelated_sandbox_keys(self):
        settings = {"sandbox": {"network": {"allowedDomains": ["x.com"]}}}
        out = self.scc.merge_sandbox_into(settings, self.desired)
        self.assertEqual(out["sandbox"]["network"]["allowedDomains"], ["x.com"])

    def test_merges_excluded_commands(self):
        desired = {
            "filesystem": {"allowWrite": [], "denyWrite": []},
            "excludedCommands": ["git commit *", "docker *"],
        }
        settings = {"sandbox": {"excludedCommands": ["docker *", "ssh *"]}}
        out = self.scc.merge_sandbox_into(settings, desired)
        self.assertEqual(
            out["sandbox"]["excludedCommands"],
            ["docker *", "ssh *", "git commit *"],
        )

    def test_excluded_commands_default_empty(self):
        out = self.scc.merge_sandbox_into({}, self.desired)
        self.assertEqual(out["sandbox"]["excludedCommands"], [])


if __name__ == "__main__":
    unittest.main()
