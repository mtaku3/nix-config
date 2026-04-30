import argparse
import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "setup-claude-code.py"


def load_module():
    spec = importlib.util.spec_from_file_location("scc", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def make_args(**overrides):
    base = dict(
        group=[], only_group=[], no_group=[],
        all_groups=False, no_default_groups=False,
    )
    base.update(overrides)
    return argparse.Namespace(**base)


class ResolveGroupsTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()
        self.cfg = {
            "defaultGroups": ["default"],
            "plugins":     {"default": [], "research": []},
            "permissions": {"default": {}, "research": {}},
            "mcp":         {"default": {}},  # no "research" group here
        }

    def test_default(self):
        sel = self.scc.resolve_groups(self.cfg, make_args())
        self.assertEqual(sel, {"default"})

    def test_no_default_groups(self):
        sel = self.scc.resolve_groups(self.cfg, make_args(no_default_groups=True))
        self.assertEqual(sel, set())

    def test_only_group(self):
        sel = self.scc.resolve_groups(self.cfg, make_args(only_group=["research"]))
        self.assertEqual(sel, {"research"})

    def test_only_group_then_group(self):
        sel = self.scc.resolve_groups(
            self.cfg, make_args(only_group=["research"], group=["default"])
        )
        self.assertEqual(sel, {"research", "default"})

    def test_no_group(self):
        sel = self.scc.resolve_groups(
            self.cfg, make_args(group=["research"], no_group=["default"])
        )
        self.assertEqual(sel, {"research"})

    def test_all_groups(self):
        sel = self.scc.resolve_groups(self.cfg, make_args(all_groups=True))
        self.assertEqual(sel, {"default", "research"})

    def test_unknown_group_raises(self):
        with self.assertRaises(self.scc.UsageError):
            self.scc.resolve_groups(self.cfg, make_args(group=["nope"]))

    def test_unknown_default_group_raises(self):
        cfg = dict(self.cfg, defaultGroups=["bogus"])
        with self.assertRaises(self.scc.UsageError):
            self.scc.resolve_groups(cfg, make_args())


class GroupsForDomainTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()

    def test_intersection(self):
        domain = {"default": [], "research": []}
        self.assertEqual(
            self.scc.groups_for_domain({"default", "research", "extra"}, domain),
            {"default", "research"},
        )


if __name__ == "__main__":
    unittest.main()
