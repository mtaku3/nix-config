import importlib.util
import json
import tempfile
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


class CollectDesiredMcpTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()

    def test_union(self):
        mcp = {
            "default":  {"a": {"command": "x"}},
            "research": {"b": {"command": "y"}},
        }
        out = self.scc.collect_desired_mcp(mcp, {"default", "research"})
        self.assertEqual(out, {"a": ({"command": "x"}, ""), "b": ({"command": "y"}, "")})

    def test_postinstall_split(self):
        mcp = {
            "default": {"a": {"command": "x", "postInstall": "echo hi"}},
        }
        out = self.scc.collect_desired_mcp(mcp, {"default"})
        self.assertEqual(out, {"a": ({"command": "x"}, "echo hi")})

    def test_collision_raises(self):
        mcp = {
            "default":  {"a": {"command": "x"}},
            "other":    {"a": {"command": "y"}},
        }
        with self.assertRaises(self.scc.UsageError):
            self.scc.collect_desired_mcp(mcp, {"default", "other"})


class ReadClaudeJsonMcpServersTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / ".claude.json"

    def tearDown(self):
        self.tmp.cleanup()

    def test_missing_returns_empty(self):
        self.assertEqual(self.scc.read_claude_json_mcp_servers(self.path), {})

    def test_invalid_returns_empty(self):
        self.path.write_text("{ not json")
        self.assertEqual(self.scc.read_claude_json_mcp_servers(self.path), {})

    def test_returns_servers(self):
        self.path.write_text(json.dumps({"mcpServers": {"a": {"command": "x"}}}))
        self.assertEqual(self.scc.read_claude_json_mcp_servers(self.path), {"a": {"command": "x"}})


class ReconcileMcpTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()

    @patch.object(load_module(), "_run_claude")
    def test_adds_missing(self, run):
        existing = {"already": {"command": "x"}}
        desired = {"already": ({"command": "x"}, ""), "new": ({"command": "y", "args": []}, "")}
        run.return_value = MagicMock(stdout="", returncode=0)

        failures = self.scc.reconcile_mcp(desired, existing, dry_run=False)
        self.assertEqual(failures, 0)
        cmds = [tuple(c.args[0]) for c in run.call_args_list]
        self.assertEqual(len(cmds), 1)
        self.assertEqual(cmds[0][:3], ("mcp", "add-json", "new"))
        self.assertEqual(json.loads(cmds[0][3]), {"command": "y", "args": []})
        self.assertEqual(cmds[0][4:], ("-s", "user"))

    @patch.object(load_module(), "_run_claude")
    def test_dry_run_no_calls(self, run):
        failures = self.scc.reconcile_mcp({"new": ({"command": "y"}, "")}, {}, dry_run=True)
        self.assertEqual(failures, 0)
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
