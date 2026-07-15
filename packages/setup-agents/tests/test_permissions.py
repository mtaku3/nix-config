import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "setup-agents.py"


def load_module():
    spec = importlib.util.spec_from_file_location("scc", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class CollectDesiredPermissionsTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()
        self.perms = {
            "default": {"allow": ["A1"], "deny": ["D1"], "ask": []},
            "research": {"allow": ["A2"], "deny": [], "ask": ["Q1"]},
        }

    def test_single_group(self):
        d = self.scc.collect_desired_permissions(self.perms, {"default"})
        self.assertEqual(sorted(d["allow"]), ["A1"])
        self.assertEqual(sorted(d["deny"]), ["D1"])
        self.assertEqual(sorted(d["ask"]), [])

    def test_union_groups(self):
        d = self.scc.collect_desired_permissions(self.perms, {"default", "research"})
        self.assertEqual(sorted(d["allow"]), ["A1", "A2"])
        self.assertEqual(sorted(d["deny"]), ["D1"])
        self.assertEqual(sorted(d["ask"]), ["Q1"])

    def test_empty_selection(self):
        d = self.scc.collect_desired_permissions(self.perms, set())
        self.assertEqual(d, {"allow": [], "deny": [], "ask": []})


class MergePermissionsTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()

    def test_union_preserves_user_first(self):
        settings = {"permissions": {"allow": ["UserA"], "deny": ["UserD"]}}
        desired = {"allow": ["A1", "UserA"], "deny": [], "ask": ["Q1"]}
        out = self.scc.merge_permissions_into(settings, desired)
        self.assertEqual(out["permissions"]["allow"], ["UserA", "A1"])
        self.assertEqual(out["permissions"]["deny"], ["UserD"])
        self.assertEqual(out["permissions"]["ask"], ["Q1"])

    def test_creates_permissions_block(self):
        out = self.scc.merge_permissions_into({}, {"allow": ["A"], "deny": [], "ask": []})
        self.assertEqual(out["permissions"]["allow"], ["A"])

    def test_preserves_unrelated_keys(self):
        settings = {"model": "opus", "permissions": {"defaultMode": "auto"}}
        out = self.scc.merge_permissions_into(settings, {"allow": ["A"], "deny": [], "ask": []})
        self.assertEqual(out["model"], "opus")
        self.assertEqual(out["permissions"]["defaultMode"], "auto")
        self.assertEqual(out["permissions"]["allow"], ["A"])


if __name__ == "__main__":
    unittest.main()
