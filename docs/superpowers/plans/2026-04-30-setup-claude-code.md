# `setup-claude-code` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `pkgs.setup-claude-code` — a flake-exported command that brings a fresh Claude Code installation in line with a Nix-declared baseline (plugins, permissions, sandbox, MCP), idempotent and additive.

**Architecture:** Snowfall-Lib package at `packages/setup-claude-code/`. `default.nix` declares opts (`defaultGroups`, `plugins`, `permissions`, `sandbox`, `mcp`) and `callPackage`s `package.nix`. `package.nix` materializes opts as a JSON file via `pkgs.formats.json` and uses `makeWrapper` to invoke a single-file Python stdlib script with `--config <path>` baked in. The script reconciles state by shelling out to `claude plugin/mcp …` and atomically rewriting `~/.claude/settings.json`.

**Tech Stack:** Nix (Snowfall-Lib), `pkgs.formats.json`, `pkgs.makeWrapper`, Python 3 stdlib (`argparse`, `subprocess`, `json`, `pathlib`, `unittest`), `claude` CLI.

**Spec:** `docs/superpowers/specs/2026-04-30-setup-claude-code-design.md`

---

## Conventions for this plan

- All file paths are relative to the repo root unless absolute.
- "Run: `nix build .#setup-claude-code -L`" means run that exact command. `-L` shows full build log.
- Python tests live at `packages/setup-claude-code/tests/` and run with `python3 -m unittest discover -s packages/setup-claude-code/tests -v`. They do not depend on Nix and do not need `claude` to be installed (subprocesses are mocked).
- Commits use Conventional Commits (`feat:`, `test:`, `chore:`). One commit per task unless a task explicitly says otherwise.
- The script itself is named `setup-claude-code.py` and lives at `packages/setup-claude-code/setup-claude-code.py`. Tests import it via `importlib.util` (since the filename has a hyphen).

---

## Task 1: Package skeleton — opts + stub script that builds

**Files:**
- Create: `packages/setup-claude-code/default.nix`
- Create: `packages/setup-claude-code/package.nix`
- Create: `packages/setup-claude-code/setup-claude-code.py`

- [ ] **Step 1: Write `packages/setup-claude-code/setup-claude-code.py`**

```python
#!/usr/bin/env python3
"""setup-claude-code: reconcile Claude Code config to a Nix-declared baseline."""

import argparse
import json
import sys


def main() -> int:
    parser = argparse.ArgumentParser(prog="setup-claude-code")
    parser.add_argument("--config", required=True, help="Path to baked config JSON")
    args = parser.parse_args()

    with open(args.config) as f:
        cfg = json.load(f)

    print(f"setup-claude-code: loaded config with keys {sorted(cfg.keys())}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Write `packages/setup-claude-code/package.nix`**

```nix
{
  python3,
  formats,
  runCommand,
  makeWrapper,
  defaultGroups,
  plugins,
  permissions,
  sandbox,
  mcp,
}: let
  configFile =
    (formats.json {}).generate "setup-claude-code.json"
    {inherit defaultGroups plugins permissions sandbox mcp;};
in
  runCommand "setup-claude-code" {
    nativeBuildInputs = [makeWrapper];
  } ''
    mkdir -p $out/bin
    makeWrapper ${python3}/bin/python3 $out/bin/setup-claude-code \
      --add-flags "${./setup-claude-code.py} --config ${configFile}"
  ''
```

- [ ] **Step 3: Write `packages/setup-claude-code/default.nix`**

```nix
{
  pkgs,
  ...
}: let
  opts = {
    defaultGroups = ["default"];

    plugins = {
      default = [
        {
          plugin = "superpowers";
          marketplace = "anthropics/claude-plugins-official";
        }
      ];
    };

    permissions = {
      default = {
        allow = [];
        deny = [];
        ask = [];
      };
    };

    sandbox = {
      filesystem = {
        allowWrite = [];
        denyWrite = [];
      };
    };

    mcp = {
      default = {};
    };
  };
in
  pkgs.callPackage ./package.nix opts
```

- [ ] **Step 4: Build the package**

Run: `nix build .#setup-claude-code -L`
Expected: build succeeds, `result/bin/setup-claude-code` exists.

- [ ] **Step 5: Smoke-run**

Run: `./result/bin/setup-claude-code`
Expected output (order of keys may differ):
```
setup-claude-code: loaded config with keys ['defaultGroups', 'mcp', 'permissions', 'plugins', 'sandbox']
```

- [ ] **Step 6: Commit**

```bash
git add packages/setup-claude-code
git commit -m "feat(setup-claude-code): package skeleton"
```

---

## Task 2: Argument parser — full CLI surface, no behavior yet

**Files:**
- Modify: `packages/setup-claude-code/setup-claude-code.py`
- Create: `packages/setup-claude-code/tests/test_args.py`

- [ ] **Step 1: Write the failing test**

Create `packages/setup-claude-code/tests/test_args.py`:

```python
import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "setup-claude-code.py"


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
        self.assertEqual(a.group, [])
        self.assertEqual(a.only_group, [])
        self.assertEqual(a.no_group, [])
        self.assertFalse(a.all_groups)
        self.assertFalse(a.no_default_groups)
        self.assertFalse(a.sandbox)
        self.assertFalse(a.no_plugins)
        self.assertFalse(a.no_permissions)
        self.assertFalse(a.no_mcp)
        self.assertFalse(a.dry_run)

    def test_repeatable_group_flags(self):
        a = self.scc.parse_args(
            ["--config", "/tmp/x.json", "--group", "a", "--group", "b", "--no-group", "c"]
        )
        self.assertEqual(a.group, ["a", "b"])
        self.assertEqual(a.no_group, ["c"])

    def test_toggles(self):
        a = self.scc.parse_args(
            ["--config", "/tmp/x.json", "--sandbox", "--no-plugins", "--dry-run"]
        )
        self.assertTrue(a.sandbox)
        self.assertTrue(a.no_plugins)
        self.assertTrue(a.dry_run)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: FAIL with `AttributeError: module 'scc' has no attribute 'parse_args'`.

- [ ] **Step 3: Implement `parse_args`**

Replace the body of `packages/setup-claude-code/setup-claude-code.py` with:

```python
#!/usr/bin/env python3
"""setup-claude-code: reconcile Claude Code config to a Nix-declared baseline."""

import argparse
import json
import sys


def parse_args(argv):
    p = argparse.ArgumentParser(prog="setup-claude-code")
    p.add_argument("--config", required=True, help="Path to baked config JSON")

    p.add_argument("--group", action="append", default=[], metavar="NAME",
                   help="Include group (repeatable)")
    p.add_argument("--only-group", action="append", default=[], metavar="NAME",
                   help="Only this group; suppresses default groups (repeatable)")
    p.add_argument("--no-group", action="append", default=[], metavar="NAME",
                   help="Exclude group (repeatable)")
    p.add_argument("--all-groups", action="store_true",
                   help="Include every defined group across all domains")
    p.add_argument("--no-default-groups", action="store_true",
                   help="Drop the default groups")

    p.add_argument("--sandbox", action="store_true",
                   help="Opt-in: write sandbox.* to settings.json")
    p.add_argument("--no-plugins", action="store_true")
    p.add_argument("--no-permissions", action="store_true")
    p.add_argument("--no-mcp", action="store_true")

    p.add_argument("--dry-run", action="store_true",
                   help="Print planned actions; no writes, no claude mutations")

    return p.parse_args(argv)


def main(argv=None):
    args = parse_args(sys.argv[1:] if argv is None else argv)
    with open(args.config) as f:
        cfg = json.load(f)
    print(f"setup-claude-code: loaded config with keys {sorted(cfg.keys())}, args={args}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: 3 passed.

- [ ] **Step 5: Commit**

```bash
git add packages/setup-claude-code/setup-claude-code.py packages/setup-claude-code/tests/test_args.py
git commit -m "feat(setup-claude-code): add CLI argument parser"
```

---

## Task 3: Group resolution

**Files:**
- Modify: `packages/setup-claude-code/setup-claude-code.py`
- Create: `packages/setup-claude-code/tests/test_groups.py`

- [ ] **Step 1: Write the failing test**

Create `packages/setup-claude-code/tests/test_groups.py`:

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: errors complaining about `UsageError`, `resolve_groups`, `groups_for_domain`.

- [ ] **Step 3: Implement group resolution**

Add to `setup-claude-code.py`, before `main()`:

```python
class UsageError(Exception):
    """Raised for bad CLI usage; main() converts to exit code 2."""


def _all_known_groups(cfg):
    known = set()
    for domain in ("plugins", "permissions", "mcp"):
        known.update(cfg.get(domain, {}).keys())
    return known


def resolve_groups(cfg, args):
    known = _all_known_groups(cfg)
    default_groups = list(cfg.get("defaultGroups", []))

    unknown_defaults = [g for g in default_groups if g not in known]
    if unknown_defaults:
        raise UsageError(
            f"defaultGroups references undefined group(s): {unknown_defaults}; "
            f"known groups: {sorted(known)}"
        )

    if args.all_groups:
        return set(known)

    if args.only_group:
        selected = set(args.only_group)
    elif args.no_default_groups:
        selected = set()
    else:
        selected = set(default_groups)

    selected.update(args.group)
    selected.difference_update(args.no_group)

    unknown = [g for g in selected if g not in known]
    if unknown:
        raise UsageError(
            f"unknown group(s): {sorted(unknown)}; known groups: {sorted(known)}"
        )
    return selected


def groups_for_domain(selected, domain_groups):
    return {g for g in selected if g in domain_groups}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: all tests in `test_args.py` and `test_groups.py` pass.

- [ ] **Step 5: Commit**

```bash
git add packages/setup-claude-code/setup-claude-code.py packages/setup-claude-code/tests/test_groups.py
git commit -m "feat(setup-claude-code): add uv-style group resolution"
```

---

## Task 4: settings.json load/save with atomic write

**Files:**
- Modify: `packages/setup-claude-code/setup-claude-code.py`
- Create: `packages/setup-claude-code/tests/test_settings.py`

- [ ] **Step 1: Write the failing test**

Create `packages/setup-claude-code/tests/test_settings.py`:

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: errors about missing `load_settings`, `save_settings`, `SettingsError`.

- [ ] **Step 3: Implement settings IO**

Add to `setup-claude-code.py`, before `main()`:

```python
import os
import tempfile
from pathlib import Path


class SettingsError(Exception):
    """Raised when ~/.claude/settings.json is unreadable; main() exits 2."""


def load_settings(path):
    p = Path(path)
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError as e:
        raise SettingsError(f"{p}: invalid JSON ({e})") from e


def save_settings(path, data):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".settings.", suffix=".json", dir=p.parent)
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        os.replace(tmp, p)
    except Exception:
        try:
            os.unlink(tmp)
        finally:
            raise
```

(Move the existing `import json` and `import sys` block at the top of the file to also include `os`, `tempfile`, and `from pathlib import Path` — keep imports at the top of the file, not inline. Re-run all tests after this consolidation.)

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/setup-claude-code/setup-claude-code.py packages/setup-claude-code/tests/test_settings.py
git commit -m "feat(setup-claude-code): add settings.json atomic IO"
```

---

## Task 5: Permissions union-merge

**Files:**
- Modify: `packages/setup-claude-code/setup-claude-code.py`
- Create: `packages/setup-claude-code/tests/test_permissions.py`

- [ ] **Step 1: Write the failing test**

Create `packages/setup-claude-code/tests/test_permissions.py`:

```python
import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "setup-claude-code.py"


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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: errors about `collect_desired_permissions`, `merge_permissions_into`.

- [ ] **Step 3: Implement**

Add to `setup-claude-code.py`:

```python
def _unique_in_order(seq):
    seen = set()
    out = []
    for item in seq:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out


def collect_desired_permissions(perms_by_group, selected):
    out = {"allow": [], "deny": [], "ask": []}
    for g in selected:
        block = perms_by_group.get(g, {})
        for k in ("allow", "deny", "ask"):
            out[k].extend(block.get(k, []))
    return {k: _unique_in_order(v) for k, v in out.items()}


def merge_permissions_into(settings, desired):
    out = dict(settings)
    perms = dict(out.get("permissions", {}))
    for k in ("allow", "deny", "ask"):
        current = perms.get(k, [])
        perms[k] = _unique_in_order(list(current) + list(desired.get(k, [])))
    out["permissions"] = perms
    return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/setup-claude-code/setup-claude-code.py packages/setup-claude-code/tests/test_permissions.py
git commit -m "feat(setup-claude-code): permissions union-merge"
```

---

## Task 6: Sandbox merge (opt-in)

**Files:**
- Modify: `packages/setup-claude-code/setup-claude-code.py`
- Create: `packages/setup-claude-code/tests/test_sandbox.py`

- [ ] **Step 1: Write the failing test**

Create `packages/setup-claude-code/tests/test_sandbox.py`:

```python
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


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: error about `merge_sandbox_into`.

- [ ] **Step 3: Implement**

Add to `setup-claude-code.py`:

```python
def merge_sandbox_into(settings, desired):
    out = dict(settings)
    sb = dict(out.get("sandbox", {}))
    sb["enabled"] = True

    fs_in = dict(sb.get("filesystem", {}))
    fs_desired = desired.get("filesystem", {}) or {}
    for k in ("allowWrite", "denyWrite"):
        fs_in[k] = _unique_in_order(list(fs_in.get(k, [])) + list(fs_desired.get(k, [])))
    sb["filesystem"] = fs_in

    out["sandbox"] = sb
    return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/setup-claude-code/setup-claude-code.py packages/setup-claude-code/tests/test_sandbox.py
git commit -m "feat(setup-claude-code): opt-in sandbox merge"
```

---

## Task 7: Plugin reconcile (subprocess-driven)

**Files:**
- Modify: `packages/setup-claude-code/setup-claude-code.py`
- Create: `packages/setup-claude-code/tests/test_plugins.py`

- [ ] **Step 1: Write the failing test**

Create `packages/setup-claude-code/tests/test_plugins.py`:

```python
import importlib.util
import json
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

SCRIPT = Path(__file__).resolve().parents[1] / "setup-claude-code.py"


def load_module():
    spec = importlib.util.spec_from_file_location("scc", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


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
        # marketplace list (empty), then list again after add, then plugin list (empty)
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: errors about missing functions.

- [ ] **Step 3: Implement**

Add to `setup-claude-code.py`:

```python
import subprocess


def _run_claude(args, capture=True, check=True):
    """Run `claude <args...>`. Returns CompletedProcess. Raises on non-zero if check=True."""
    return subprocess.run(
        ["claude", *args],
        capture_output=capture,
        text=True,
        check=check,
    )


def collect_desired_plugins(plugins_by_group, selected):
    out = []
    seen = set()
    for g in selected:
        for entry in plugins_by_group.get(g, []):
            key = (entry["plugin"], entry["marketplace"])
            if key not in seen:
                seen.add(key)
                out.append(key)
    return out


def resolve_marketplace_name(listing, source):
    for m in listing:
        # github: repo == "owner/name"; url/path: source-keyed
        for key in ("repo", "url", "path", "directory", "git", "npm", "file"):
            if m.get(key) == source:
                return m["name"]
    return None


def _list_marketplaces():
    cp = _run_claude(["plugin", "marketplace", "list", "--json"])
    return json.loads(cp.stdout or "[]")


def _list_installed_plugins():
    cp = _run_claude(["plugin", "list", "--json"])
    return {entry["id"] for entry in json.loads(cp.stdout or "[]")}


def reconcile_plugins(desired, dry_run):
    """desired: list of (plugin, marketplace_source). Returns failure count."""
    failures = 0
    listing = _list_marketplaces()

    # Register missing marketplaces
    for _, source in desired:
        if resolve_marketplace_name(listing, source) is None:
            print(f"+ claude plugin marketplace add {source}", flush=True)
            if not dry_run:
                try:
                    _run_claude(["plugin", "marketplace", "add", source])
                except subprocess.CalledProcessError as e:
                    print(f"  ! failed: {e}", file=sys.stderr)
                    failures += 1
                    continue
                listing = _list_marketplaces()

    installed = _list_installed_plugins()
    for plugin, source in desired:
        name = resolve_marketplace_name(listing, source)
        if name is None:
            # marketplace add failed earlier or registry didn't surface it
            print(f"  ! cannot resolve marketplace name for {source}", file=sys.stderr)
            failures += 1
            continue
        plugin_id = f"{plugin}@{name}"
        if plugin_id in installed:
            continue
        print(f"+ claude plugin install {plugin_id}", flush=True)
        if not dry_run:
            try:
                _run_claude(["plugin", "install", plugin_id])
            except subprocess.CalledProcessError as e:
                print(f"  ! failed: {e}", file=sys.stderr)
                failures += 1
    return failures
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/setup-claude-code/setup-claude-code.py packages/setup-claude-code/tests/test_plugins.py
git commit -m "feat(setup-claude-code): plugin reconcile via claude CLI"
```

---

## Task 8: MCP reconcile

**Files:**
- Modify: `packages/setup-claude-code/setup-claude-code.py`
- Create: `packages/setup-claude-code/tests/test_mcp.py`

- [ ] **Step 1: Write the failing test**

Create `packages/setup-claude-code/tests/test_mcp.py`:

```python
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

SCRIPT = Path(__file__).resolve().parents[1] / "setup-claude-code.py"


def load_module():
    spec = importlib.util.spec_from_file_location("scc", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class CollectDesiredMcpTest(unittest.TestCase):
    def setUp(self):
        self.scc = load_module()

    def test_union(self):
        mcp = {
            "default":  {"a": {"command": "x"}},
            "research": {"b": {"command": "y"}},
        }
        out = self.scc.collect_desired_mcp(mcp, {"default", "research"})
        self.assertEqual(out, {"a": {"command": "x"}, "b": {"command": "y"}})

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
        desired = {"already": {"command": "x"}, "new": {"command": "y", "args": []}}
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
        failures = self.scc.reconcile_mcp({"new": {"command": "y"}}, {}, dry_run=True)
        self.assertEqual(failures, 0)
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: errors about missing functions.

- [ ] **Step 3: Implement**

Add to `setup-claude-code.py`:

```python
def collect_desired_mcp(mcp_by_group, selected):
    out = {}
    for g in selected:
        for name, spec in mcp_by_group.get(g, {}).items():
            if name in out and out[name] != spec:
                raise UsageError(
                    f"mcp server name collision across groups: {name!r}"
                )
            out[name] = spec
    return out


def read_claude_json_mcp_servers(path):
    p = Path(path)
    if not p.exists():
        return {}
    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError:
        return {}
    return data.get("mcpServers", {}) or {}


def reconcile_mcp(desired, existing, dry_run):
    failures = 0
    for name, spec in desired.items():
        if name in existing:
            continue
        spec_json = json.dumps(spec)
        print(f"+ claude mcp add-json {name} <json> -s user", flush=True)
        if not dry_run:
            try:
                _run_claude(["mcp", "add-json", name, spec_json, "-s", "user"])
            except subprocess.CalledProcessError as e:
                print(f"  ! failed: {e}", file=sys.stderr)
                failures += 1
    return failures
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/setup-claude-code/setup-claude-code.py packages/setup-claude-code/tests/test_mcp.py
git commit -m "feat(setup-claude-code): mcp reconcile via claude CLI"
```

---

## Task 9: Wire `main()` — preflight, dispatch, exit codes

**Files:**
- Modify: `packages/setup-claude-code/setup-claude-code.py`
- Create: `packages/setup-claude-code/tests/test_main.py`

- [ ] **Step 1: Write the failing test**

Create `packages/setup-claude-code/tests/test_main.py`:

```python
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "setup-claude-code.py"


def load_module():
    spec = importlib.util.spec_from_file_location("scc", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def write_cfg(tmp, cfg):
    p = Path(tmp) / "cfg.json"
    p.write_text(json.dumps(cfg))
    return p


CFG = {
    "defaultGroups": ["default"],
    "plugins":     {"default": []},
    "permissions": {"default": {"allow": [], "deny": [], "ask": []}},
    "sandbox":     {"filesystem": {"allowWrite": [], "denyWrite": []}},
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: failures referencing missing wiring (preflight short-circuit, exit 2 paths).

- [ ] **Step 3: Implement `main()`**

Replace the existing `main()` in `setup-claude-code.py` with:

```python
import shutil


def _settings_path():
    return Path(os.environ.get("HOME", "")) / ".claude" / "settings.json"


def _claude_json_path():
    return Path(os.environ.get("HOME", "")) / ".claude.json"


def main(argv=None):
    args = parse_args(sys.argv[1:] if argv is None else argv)

    if shutil.which("claude") is None:
        print("setup-claude-code: claude-code is not installed; nothing to do.",
              file=sys.stderr)
        return 0

    try:
        with open(args.config) as f:
            cfg = json.load(f)
        selected = resolve_groups(cfg, args)
    except UsageError as e:
        print(f"setup-claude-code: {e}", file=sys.stderr)
        return 2

    settings_path = _settings_path()
    try:
        settings = load_settings(settings_path)
    except SettingsError as e:
        print(f"setup-claude-code: {e}", file=sys.stderr)
        return 2

    rc = 0

    if not args.no_plugins:
        desired = collect_desired_plugins(
            cfg.get("plugins", {}),
            groups_for_domain(selected, cfg.get("plugins", {})),
        )
        rc |= 1 if reconcile_plugins(desired, args.dry_run) else 0

    if not args.no_permissions:
        desired = collect_desired_permissions(
            cfg.get("permissions", {}),
            groups_for_domain(selected, cfg.get("permissions", {})),
        )
        new_settings = merge_permissions_into(settings, desired)
        if new_settings != settings:
            print("+ update permissions in settings.json", flush=True)
            if not args.dry_run:
                save_settings(settings_path, new_settings)
                settings = new_settings

    if args.sandbox:
        new_settings = merge_sandbox_into(settings, cfg.get("sandbox", {}))
        if new_settings != settings:
            print("+ update sandbox in settings.json", flush=True)
            if not args.dry_run:
                save_settings(settings_path, new_settings)
                settings = new_settings

    if not args.no_mcp:
        try:
            desired = collect_desired_mcp(
                cfg.get("mcp", {}),
                groups_for_domain(selected, cfg.get("mcp", {})),
            )
        except UsageError as e:
            print(f"setup-claude-code: {e}", file=sys.stderr)
            return 2
        existing = read_claude_json_mcp_servers(_claude_json_path())
        rc |= 1 if reconcile_mcp(desired, existing, args.dry_run) else 0

    return rc
```

(Delete the previous stub `main()` and the now-unused `print(f"setup-claude-code: loaded config…")` line.)

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest discover -s packages/setup-claude-code/tests -v`
Expected: all tests pass.

- [ ] **Step 5: Verify build still green**

Run: `nix build .#setup-claude-code -L`
Expected: succeeds.

- [ ] **Step 6: Commit**

```bash
git add packages/setup-claude-code/setup-claude-code.py packages/setup-claude-code/tests/test_main.py
git commit -m "feat(setup-claude-code): wire main with preflight and exit codes"
```

---

## Task 10: Manual smoke test against real `claude`

**Files:**
- (no code changes; verification only)

- [ ] **Step 1: Build and dry-run**

Run: `nix build .#setup-claude-code -L && ./result/bin/setup-claude-code --dry-run`
Expected: prints `+ claude plugin marketplace add anthropics/claude-plugins-official` (or skips if already registered) and `+ claude plugin install superpowers@claude-plugins-official` (or skips if installed). No writes to `~/.claude/settings.json` (verify mtime unchanged).

- [ ] **Step 2: Real run, then re-run for idempotency**

Run: `./result/bin/setup-claude-code` then `./result/bin/setup-claude-code` again.
Expected: first run may install; second run prints nothing under any `+ …` line and exits 0. Verify `~/.claude/settings.json` is still valid JSON (`python3 -m json.tool ~/.claude/settings.json >/dev/null`).

- [ ] **Step 3: Sandbox opt-in**

Run: `./result/bin/setup-claude-code --sandbox --dry-run`
Expected: prints `+ update sandbox in settings.json` only if the desired filesystem lists are non-empty in `default.nix`. (With the empty-list defaults from Task 1, this will be a no-op even with `--sandbox` — that's expected.)

- [ ] **Step 4: Unknown group**

Run: `./result/bin/setup-claude-code --group bogus`; observe stderr message and `echo $?`.
Expected: exit code 2, error message lists known groups.

- [ ] **Step 5: No commit**

This task only verifies behavior; no code change to commit.

---

## Task 11: Add `setup-claude-code` to the home module

**Files:**
- Modify: `modules/home/app/dev/claude-code/default.nix`

- [ ] **Step 1: Add the package to `home.packages`**

Edit `modules/home/app/dev/claude-code/default.nix`. In the `home.packages` list, add `pkgs.setup-claude-code` next to the existing entries:

```nix
    home.packages = [
      claudeWrapper
      pkgs.setup-claude-code
      pkgs.nodejs
      pkgs.python3
      pkgs.uv
      pkgs.socat
    ] ++ lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.bubblewrap;
```

- [ ] **Step 2: Verify a host build still evaluates**

Find the active host (e.g. `nix flake show` lists `nixosConfigurations` / `homeConfigurations`) and run a dry build for one that enables `capybara.app.dev.claude-code`. Example:

Run: `nix build '.#nixosConfigurations.<host>.config.system.build.toplevel' --dry-run -L`
(Substitute `<host>` for an actual host name from `nix flake show`.)
Expected: evaluation completes with no `setup-claude-code`-related errors.

- [ ] **Step 3: Commit**

```bash
git add modules/home/app/dev/claude-code/default.nix
git commit -m "feat(claude-code): expose setup-claude-code via home module"
```

---

## Self-review notes

- **Spec coverage:** opts shape (Task 1), defaultGroups + group resolution (Tasks 1, 3), CLI flags (Task 2), permissions/sandbox/mcp/plugins reconcile (Tasks 5–8), preflight + exit codes + dry-run (Task 9), home-module integration (Task 11), manual smoke (Task 10).
- **Open items from the spec** (marketplace source-→name mapping, `mcp add-json` field coverage, `formats.json` shape acceptance) are exercised at Task 10 against a real `claude` install. Any deviation discovered there is a change-request, not a plan failure.
- **Not in scope here:** automated end-to-end test against real `claude` (manual only); HTTP/SSE MCP transport (works via passthrough but not exercised by tests); `defaultMode` and other `permissions.*` keys beyond `allow/deny/ask` (untouched by design).
