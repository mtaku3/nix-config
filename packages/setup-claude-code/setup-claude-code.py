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


def main(argv=None):
    args = parse_args(sys.argv[1:] if argv is None else argv)
    with open(args.config) as f:
        cfg = json.load(f)
    print(f"setup-claude-code: loaded config with keys {sorted(cfg.keys())}, args={args}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
