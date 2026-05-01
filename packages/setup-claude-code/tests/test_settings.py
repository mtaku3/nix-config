import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "setup-claude-code.py"


def load_module():
    spec = importlib.util.spec_from_file_location("scc", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class SettingsIOTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / "settings.json"

    def tearDown(self):
        self.tmp.cleanup()

    def test_load_missing_returns_empty(self):
        self.assertEqual(self.scc.load_settings(self.path), {})

    def test_load_invalid_raises(self):
        self.path.write_text("{ not json")
        with self.assertRaises(self.scc.SettingsError):
            self.scc.load_settings(self.path)

    def test_save_atomic_roundtrip(self):
        data = {"permissions": {"allow": ["Read(*)"]}}
        self.scc.save_settings(self.path, data)
        self.assertEqual(json.loads(self.path.read_text()), data)

    def test_save_creates_parent_dir(self):
        nested = Path(self.tmp.name) / "sub" / "settings.json"
        self.scc.save_settings(nested, {"a": 1})
        self.assertEqual(json.loads(nested.read_text()), {"a": 1})


if __name__ == "__main__":
    unittest.main()
