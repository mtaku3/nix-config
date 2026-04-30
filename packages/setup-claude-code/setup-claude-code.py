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
