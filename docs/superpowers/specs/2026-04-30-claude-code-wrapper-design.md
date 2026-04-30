# claude-code wrapper module design

## Context

The current `modules/home/app/dev/claude-code/default.nix` adds `~/.local/bin`
to `home.sessionPath` so the installer-managed `claude` binary is reachable.
This works but has two drawbacks:

- Anything else dropped into `~/.local/bin` silently enters `PATH`.
- There is no hook for exporting secrets (e.g. API keys from agenix) before
  `claude` runs.

This spec replaces the bare PATH entry with a Nix-built wrapper script that
performs an installation check and runs a configurable pre-start snippet
before `exec`'ing the real binary.

## Goals

- `claude` on `PATH` is a Nix-managed wrapper, not the installer's binary.
- If the installer binary is missing, the wrapper prints install guidance and
  exits non-zero — no surprise network calls, no auto-install.
- A new `preStart` option lets users (or sibling host modules) inject shell
  lines that run before the real binary is invoked. Intended use is exporting
  secrets read from agenix-managed files.

## Non-goals

- A structured `secretEnv` attrset. `preStart` is the single mechanism;
  declarative env-var maps can be added later if a pattern emerges.
- Auto-installing or self-updating `claude`. The installer remains the source
  of truth at `~/.local/bin/claude`.
- Replacing `nodejs` / `python3` / `uv` / `socat` / `bubblewrap` runtime deps.

## Architecture

A wrapper named `claude` is built with `pkgs.writeShellApplication` and added
to `home.packages`. Because Home Manager's nix-profile bin directory comes
before `~/.local/bin` in the resolved `PATH`, this wrapper takes precedence.
The wrapper invokes the installer-managed binary at `~/.local/bin/claude` by
absolute path, so `~/.local/bin` no longer needs to be on `PATH`.

The `.local/bin` impermanence directory entry stays — the installer writes
self-update state there and that state must persist across reboots.

## Module option

```nix
capybara.app.dev.claude-code.preStart = mkOption {
  type = types.lines;
  default = "";
  description = ''
    Shell snippet sourced by the claude wrapper before exec'ing the real
    binary. Use to export secrets read from agenix-managed files, e.g.
      export ANTHROPIC_API_KEY=$(cat ''${config.age.secrets.anthropic.path})
  '';
};
```

`types.lines` allows multiple modules / host configs to append snippets
without clobbering each other.

## Wrapper script

```bash
#!/usr/bin/env bash
set -euo pipefail

REAL=$HOME/.local/bin/claude

if [[ ! -x $REAL ]]; then
  cat >&2 <<'EOF'
claude-code is not installed.

Install with:
  curl -fsSL https://claude.ai/install.sh | bash

Docs: https://docs.claude.com/en/docs/claude-code/setup
EOF
  exit 127
fi

# preStart snippet (Nix-interpolated; may export env vars)
${cfg.preStart}

exec "$REAL" "$@"
```

Notes:

- `${cfg.preStart}` is plain Nix string interpolation — the option's lines
  are spliced directly into the script body at evaluation time. The snippet
  runs in the wrapper's own shell (no subshell), so `export` lines affect
  the environment seen by `exec claude`.
- `exec` ensures signals and the controlling tty pass through transparently.
- Exit code `127` matches POSIX "command not found".

## Changes to `default.nix`

- Add the `preStart` option as specified above.
- Build the wrapper with `pkgs.writeShellApplication { name = "claude"; text = ...; }`,
  substituting `cfg.preStart` into the script body.
- Add the wrapper derivation to `home.packages`.
- Remove `"$HOME/.local/bin"` from `home.sessionPath`. Keep
  `"$HOME/.npm-global/bin"`.
- Leave `home.file.".npmrc"`, `capybara.impermanence.directories`, and
  `capybara.impermanence.files` untouched.

## Behavior summary

| Situation                                            | Result                                          |
| ---------------------------------------------------- | ----------------------------------------------- |
| `~/.local/bin/claude` missing                        | Print install command + docs URL, exit 127.    |
| `~/.local/bin/claude` present, `preStart` empty      | `exec` real binary with original args/env.     |
| `~/.local/bin/claude` present, `preStart` non-empty  | Run snippet, then `exec` real binary.          |
| `preStart` snippet fails (`set -e`)                  | Wrapper exits with that failure; real binary not invoked. |

## Migration

Users on a host that enables `capybara.app.dev.claude-code` need no action;
the wrapper is wired up automatically. Anyone who previously relied on
`~/.local/bin` being on `PATH` for some other tool must add it back in their
own host config.
