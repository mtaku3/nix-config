import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "setup-agents.py"

_CACHED_MOD = None


def load_module():
    global _CACHED_MOD
    if _CACHED_MOD is None:
        spec = importlib.util.spec_from_file_location("scc", SCRIPT)
        _CACHED_MOD = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_CACHED_MOD)
    return _CACHED_MOD


def write_cfg(tmp, cfg):
    p = Path(tmp) / "cfg.json"
    p.write_text(json.dumps(cfg))
    return p


CFG = {
    "defaultGroups": ["default"],
    "plugins":     {"default": []},
    "permissions": {"default": {"allow": [], "deny": [], "ask": []}},
    "mcp":         {"default": {}},
}


class MainTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()
        self.tmp = tempfile.TemporaryDirectory()
        self.cfg_path = write_cfg(self.tmp.name, CFG)

    def tearDown(self):
        self.tmp.cleanup()

    @patch("shutil.which", return_value=None)
    def test_preflight_no_claude_exits_0(self, _which):
        rc = self.scc.main(["--config", str(self.cfg_path)])
        self.assertEqual(rc, 0)

    @patch("shutil.which", return_value="/usr/bin/claude")
    def test_unknown_group_exits_2(self, _which):
        rc = self.scc.main(["--config", str(self.cfg_path), "--group", "bogus"])
        self.assertEqual(rc, 2)

    @patch("shutil.which", return_value="/usr/bin/claude")
    def test_invalid_settings_exits_2(self, _which):
        # Point HOME to a tempdir with corrupt settings.json
        home = Path(self.tmp.name) / "home"
        (home / ".claude").mkdir(parents=True)
        (home / ".claude" / "settings.json").write_text("{ not json")
        with patch.dict("os.environ", {"HOME": str(home)}):
            rc = self.scc.main([
                "--config", str(self.cfg_path),
                "--no-plugins", "--no-mcp",  # avoid hitting `claude`
            ])
        self.assertEqual(rc, 2)


if __name__ == "__main__":
    unittest.main()
