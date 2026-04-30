import importlib.util
import json
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

SCRIPT = Path(__file__).resolve().parents[1] / "setup-claude-code.py"

_CACHED_MOD = None


def load_module():
    global _CACHED_MOD
    if _CACHED_MOD is None:
        spec = importlib.util.spec_from_file_location("scc", SCRIPT)
        _CACHED_MOD = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_CACHED_MOD)
    return _CACHED_MOD


class CollectDesiredPluginsTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()
        self.plugins = {
            "default": [
                {"plugin": "superpowers", "marketplace": "anthropics/claude-plugins-official"}
            ],
            "research": [
                {"plugin": "deep-research", "marketplace": "obra/superpowers-marketplace"}
            ],
        }

    def test_collect(self):
        out = self.scc.collect_desired_plugins(self.plugins, {"default"})
        self.assertEqual(out, [
            ("superpowers", "anthropics/claude-plugins-official"),
        ])

    def test_collect_two_groups_dedupes(self):
        plugins = {
            "a": [{"plugin": "p", "marketplace": "m"}],
            "b": [{"plugin": "p", "marketplace": "m"}],
        }
        out = self.scc.collect_desired_plugins(plugins, {"a", "b"})
        self.assertEqual(out, [("p", "m")])


class ResolveMarketplaceNameTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()
        self.listing = [
            {"name": "claude-plugins-official", "source": "github",
             "repo": "anthropics/claude-plugins-official",
             "installLocation": "/x"},
            {"name": "my-stuff", "source": "url",
             "url": "https://example.com/marketplace.json"},
        ]

    def test_github_repo_match(self):
        n = self.scc.resolve_marketplace_name(
            self.listing, "anthropics/claude-plugins-official"
        )
        self.assertEqual(n, "claude-plugins-official")

    def test_url_match(self):
        n = self.scc.resolve_marketplace_name(
            self.listing, "https://example.com/marketplace.json"
        )
        self.assertEqual(n, "my-stuff")

    def test_no_match_returns_none(self):
        self.assertIsNone(self.scc.resolve_marketplace_name(self.listing, "nope/nope"))


class ReconcilePluginsTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()

    @patch.object(load_module(), "_run_claude")
    def test_installs_missing_after_registering_marketplace(self, run):
        # marketplace list (empty), then add, then list again, then plugin list (empty), then install
        run.side_effect = [
            MagicMock(stdout="[]", returncode=0),                                   # marketplace list --json (empty)
            MagicMock(stdout="", returncode=0),                                     # marketplace add
            MagicMock(stdout=json.dumps([                                           # marketplace list --json (after add)
                {"name": "claude-plugins-official", "source": "github",
                 "repo": "anthropics/claude-plugins-official"}
            ]), returncode=0),
            MagicMock(stdout="[]", returncode=0),                                   # plugin list --json
            MagicMock(stdout="", returncode=0),                                     # plugin install
        ]
        failures = self.scc.reconcile_plugins(
            [("superpowers", "anthropics/claude-plugins-official")], dry_run=False
        )
        self.assertEqual(failures, 0)
        cmds = [tuple(c.args[0]) for c in run.call_args_list]
        self.assertEqual(cmds, [
            ("plugin", "marketplace", "list", "--json"),
            ("plugin", "marketplace", "add", "anthropics/claude-plugins-official"),
            ("plugin", "marketplace", "list", "--json"),
            ("plugin", "list", "--json"),
            ("plugin", "install", "superpowers@claude-plugins-official"),
        ])

    @patch.object(load_module(), "_run_claude")
    def test_skip_when_already_installed(self, run):
        run.side_effect = [
            MagicMock(stdout=json.dumps([                                           # marketplace list
                {"name": "claude-plugins-official", "source": "github",
                 "repo": "anthropics/claude-plugins-official"}
            ]), returncode=0),
            MagicMock(stdout=json.dumps([                                           # plugin list
                {"id": "superpowers@claude-plugins-official"}
            ]), returncode=0),
        ]
        failures = self.scc.reconcile_plugins(
            [("superpowers", "anthropics/claude-plugins-official")], dry_run=False
        )
        self.assertEqual(failures, 0)
        cmds = [tuple(c.args[0]) for c in run.call_args_list]
        self.assertEqual(cmds, [
            ("plugin", "marketplace", "list", "--json"),
            ("plugin", "list", "--json"),
        ])

    @patch.object(load_module(), "_run_claude")
    def test_dry_run_only_reads(self, run):
        run.side_effect = [
            MagicMock(stdout=json.dumps([
                {"name": "claude-plugins-official", "source": "github",
                 "repo": "anthropics/claude-plugins-official"}
            ]), returncode=0),
            MagicMock(stdout="[]", returncode=0),
        ]
        failures = self.scc.reconcile_plugins(
            [("superpowers", "anthropics/claude-plugins-official")], dry_run=True
        )
        self.assertEqual(failures, 0)
        cmds = [tuple(c.args[0]) for c in run.call_args_list]
        # Should NOT include plugin install
        self.assertNotIn(("plugin", "install", "superpowers@claude-plugins-official"), cmds)


if __name__ == "__main__":
    unittest.main()
