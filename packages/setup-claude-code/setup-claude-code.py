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
