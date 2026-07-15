import importlib.util
import json
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

SCRIPT = Path(__file__).resolve().parents[1] / "setup-agents.py"

_CACHED_MOD = None


def load_module():
    global _CACHED_MOD
    if _CACHED_MOD is None:
        spec = importlib.util.spec_from_file_location("scc", SCRIPT)
        _CACHED_MOD = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_CACHED_MOD)
    return _CACHED_MOD


LIST_JSON = json.dumps([
    {
        "name": "already",
        "enabled": True,
        "transport": {"type": "stdio", "command": "x", "args": [], "env": None},
    },
])


class CodexAddArgsTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()

    def test_stdio_basic(self):
        args = self.scc.codex_add_args("srv", {"command": "uvx", "args": ["--from", "p"]})
        self.assertEqual(args, ["mcp", "add", "srv", "--", "uvx", "--from", "p"])

    def test_stdio_with_env(self):
        args = self.scc.codex_add_args(
            "srv", {"command": "x", "args": ["a"], "env": {"K": "V"}}
        )
        self.assertEqual(args, ["mcp", "add", "srv", "--env", "K=V", "--", "x", "a"])

    def test_stdio_type_explicit(self):
        args = self.scc.codex_add_args("srv", {"type": "stdio", "command": "x"})
        self.assertEqual(args, ["mcp", "add", "srv", "--", "x"])

    def test_url(self):
        args = self.scc.codex_add_args("srv", {"url": "https://example.com/mcp"})
        self.assertEqual(args, ["mcp", "add", "srv", "--url", "https://example.com/mcp"])

    def test_unsupported_returns_none(self):
        self.assertIsNone(self.scc.codex_add_args("srv", {}))
        self.assertIsNone(self.scc.codex_add_args("srv", {"type": "sse", "command": "x"}))


class ListCodexMcpServersTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()

    @patch.object(load_module(), "_run_codex")
    def test_parses_names(self, run):
        run.return_value = MagicMock(stdout=LIST_JSON, returncode=0)
        self.assertEqual(self.scc.list_codex_mcp_servers(), {"already"})

    @patch.object(load_module(), "_run_codex")
    def test_empty_stdout(self, run):
        run.return_value = MagicMock(stdout="", returncode=0)
        self.assertEqual(self.scc.list_codex_mcp_servers(), set())


def _add_cmds(run):
    return [
        tuple(c.args[0])
        for c in run.call_args_list
        if tuple(c.args[0])[:2] == ("mcp", "add")
    ]


class ReconcileCodexMcpTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()

    @patch.object(load_module(), "_run_codex")
    def test_adds_only_missing(self, run):
        run.return_value = MagicMock(stdout=LIST_JSON, returncode=0)
        desired = {
            "already": ({"command": "x"}, ""),
            "new": ({"command": "y", "args": ["z"]}, ""),
        }
        failures = self.scc.reconcile_codex_mcp(desired, dry_run=False)
        self.assertEqual(failures, 0)
        self.assertEqual(_add_cmds(run), [("mcp", "add", "new", "--", "y", "z")])

    @patch.object(load_module(), "_run_codex")
    def test_converged_noop(self, run):
        run.return_value = MagicMock(stdout=LIST_JSON, returncode=0)
        failures = self.scc.reconcile_codex_mcp({"already": ({"command": "x"}, "")}, dry_run=False)
        self.assertEqual(failures, 0)
        self.assertEqual(_add_cmds(run), [])

    @patch.object(load_module(), "_run_codex")
    def test_dry_run_no_add(self, run):
        run.return_value = MagicMock(stdout="[]", returncode=0)
        failures = self.scc.reconcile_codex_mcp({"new": ({"command": "y"}, "")}, dry_run=True)
        self.assertEqual(failures, 0)
        self.assertEqual(_add_cmds(run), [])

    @patch.object(load_module(), "_run_codex")
    def test_unsupported_skipped(self, run):
        run.return_value = MagicMock(stdout="[]", returncode=0)
        failures = self.scc.reconcile_codex_mcp({"bad": ({"type": "sse"}, "")}, dry_run=False)
        self.assertEqual(failures, 0)
        self.assertEqual(_add_cmds(run), [])


if __name__ == "__main__":
    unittest.main()
