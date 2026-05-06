#!/usr/bin/env python3
"""setup-claude-code: reconcile Claude Code config to a Nix-declared baseline."""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


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
    p.add_argument("--enable-plugins", action="store_true",
                   help="Also enable pre-existing plugins that are currently "
                        "disabled (newly installed plugins are always enabled)")
    p.add_argument("--no-permissions", action="store_true")
    p.add_argument("--no-mcp", action="store_true")

    p.add_argument("--dry-run", action="store_true",
                   help="Print planned actions; no writes, no claude mutations")

    return p.parse_args(argv)


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


def merge_sandbox_into(settings, desired):
    out = dict(settings)
    sb = dict(out.get("sandbox", {}))
    sb["enabled"] = True

    fs_in = dict(sb.get("filesystem", {}))
    fs_desired = desired.get("filesystem", {}) or {}
    for k in ("allowWrite", "denyWrite"):
        fs_in[k] = _unique_in_order(list(fs_in.get(k, [])) + list(fs_desired.get(k, [])))
    sb["filesystem"] = fs_in

    sb["excludedCommands"] = _unique_in_order(
        list(sb.get("excludedCommands", [])) + list(desired.get("excludedCommands", []))
    )

    out["sandbox"] = sb
    return out


def _run_claude(args, capture=True, check=True):
    """Run `claude <args...>`. Returns CompletedProcess. Raises on non-zero if check=True."""
    return subprocess.run(
        ["claude", *args],
        capture_output=capture,
        text=True,
        check=check,
    )


def collect_desired_plugins(plugins_by_group, selected):
    """Return deduped list of (plugin, marketplace, postinstall) tuples across the selected groups."""
    out = []
    seen = set()
    for g in selected:
        for entry in plugins_by_group.get(g, []):
            key = (entry["plugin"], entry["marketplace"])
            if key not in seen:
                seen.add(key)
                out.append((entry["plugin"], entry["marketplace"], entry.get("postInstall", "")))
    return out


def _run_postinstall(label, script, dry_run):
    """Run a bash postinstall snippet. Returns 1 on failure, else 0."""
    if not script or not script.strip():
        return 0
    print(f"+ postinstall: {label}", flush=True)
    if dry_run:
        return 0
    try:
        subprocess.run(["bash", "-c", script], check=True)
    except subprocess.CalledProcessError as e:
        print(f"  ! postinstall failed for {label}: {e}", file=sys.stderr)
        return 1
    return 0


def resolve_marketplace_name(listing, source):
    """Return the registered marketplace name for source, or None if not found."""
    for m in listing:
        # github: repo == "owner/name"; url/path: source-keyed
        for key in ("repo", "url", "path", "directory", "git", "npm", "file"):
            if m.get(key) == source:
                return m["name"]
    return None


def _list_marketplaces():
    """Return the current marketplace listing as a list of dicts."""
    cp = _run_claude(["plugin", "marketplace", "list", "--json"])
    return json.loads(cp.stdout or "[]")


def _list_installed_plugins():
    """Return {plugin_id: enabled_bool} for installed plugins (id = 'name@marketplace')."""
    cp = _run_claude(["plugin", "list", "--json"])
    return {
        entry["id"]: bool(entry.get("enabled", True))
        for entry in json.loads(cp.stdout or "[]")
    }


def reconcile_plugins(desired, dry_run, enable_existing=False):
    """desired: list of (plugin, marketplace_source, postinstall). Returns failure count.

    Newly installed plugins are always enabled. Pre-existing plugins that are
    currently disabled are only re-enabled when enable_existing is True.
    """
    failures = 0
    listing = _list_marketplaces()

    pending_sources = set()  # marketplaces we couldn't (or didn't) actually register in this run

    for _, source, _post in desired:
        if resolve_marketplace_name(listing, source) is None:
            print(f"+ claude plugin marketplace add {source}", flush=True)
            if dry_run:
                pending_sources.add(source)
                continue
            try:
                _run_claude(["plugin", "marketplace", "add", source])
            except subprocess.CalledProcessError as e:
                print(f"  ! failed: {e}", file=sys.stderr)
                failures += 1
                pending_sources.add(source)
                continue
            listing = _list_marketplaces()

    installed = _list_installed_plugins()
    for plugin, source, postinstall in desired:
        name = resolve_marketplace_name(listing, source)
        if name is None:
            if source in pending_sources:
                if dry_run:
                    # Marketplace not yet registered; show install would follow.
                    print(f"+ claude plugin install {plugin}@<from-{source}>", flush=True)
                    if postinstall and postinstall.strip():
                        print(f"+ postinstall: plugin {plugin}", flush=True)
                # Real-run: silently skip; the marketplace add failure already counted.
                continue
            # Genuinely surprising: marketplace listed but unmatchable.
            print(f"  ! cannot resolve marketplace name for {source}", file=sys.stderr)
            failures += 1
            continue
        plugin_id = f"{plugin}@{name}"
        if plugin_id in installed:
            if enable_existing and not installed[plugin_id]:
                print(f"+ claude plugin enable {plugin_id}", flush=True)
                if not dry_run:
                    try:
                        _run_claude(["plugin", "enable", plugin_id])
                    except subprocess.CalledProcessError as e:
                        print(f"  ! failed: {e}", file=sys.stderr)
                        failures += 1
            continue
        print(f"+ claude plugin install {plugin_id}", flush=True)
        if not dry_run:
            try:
                _run_claude(["plugin", "install", plugin_id])
            except subprocess.CalledProcessError as e:
                print(f"  ! failed: {e}", file=sys.stderr)
                failures += 1
                continue
        failures += _run_postinstall(f"plugin {plugin}", postinstall, dry_run)
    return failures


def collect_desired_mcp(mcp_by_group, selected):
    """Return merged {name: spec} across the selected groups; raise UsageError on collision.

    spec may include a `postInstall` key (bash snippet) that is split out and
    not forwarded to `claude mcp add-json`.
    """
    out = {}
    for g in selected:
        for name, raw_spec in mcp_by_group.get(g, {}).items():
            spec = {k: v for k, v in raw_spec.items() if k != "postInstall"}
            postinstall = raw_spec.get("postInstall", "")
            if name in out and (out[name][0] != spec or out[name][1] != postinstall):
                raise UsageError(
                    f"mcp server name collision across groups: {name!r}"
                )
            out[name] = (spec, postinstall)
    return out


def read_claude_json_mcp_servers(path):
    """Best-effort read of mcpServers from ~/.claude.json. Missing/invalid -> {}."""
    p = Path(path)
    if not p.exists():
        return {}
    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError:
        return {}
    return data.get("mcpServers", {}) or {}


def reconcile_mcp(desired, existing, dry_run):
    """Add missing MCP servers via `claude mcp add-json -s user`. Returns failure count."""
    failures = 0
    for name, (spec, postinstall) in desired.items():
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
                continue
        failures += _run_postinstall(f"mcp {name}", postinstall, dry_run)
    return failures


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
        rc |= 1 if reconcile_plugins(desired, args.dry_run, args.enable_plugins) else 0

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

    rc |= 1 if _run_postinstall("global", cfg.get("postInstall", ""), args.dry_run) else 0

    return rc


if __name__ == "__main__":
    sys.exit(main())
