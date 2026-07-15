# `setup-agents` + codex support — design

## Context

`setup-claude-code` is a hand-run Python reconciler that brings a freshly
installed Claude Code in line with a Nix-declared baseline: install missing
plugins, register marketplaces, add MCP servers, and union-merge
permission/sandbox rules into `~/.claude/settings.json` and `~/.claude.json`.
The home-manager module `modules/home/app/dev/claude-code` only wraps the
installer-managed `claude` binary so a `preStart` snippet (secret exports) runs
first.

We now also use **Codex** (OpenAI's coding-agent CLI). It is installed and
updated the same way — an installer-managed binary at `~/.local/bin/codex` — and
similarly ships no Nix-managed configuration. Codex config lives in
`$CODEX_HOME/config.toml` (default `~/.codex/config.toml`, TOML). Codex has **no
plugin system** and **no Claude-style allow/deny permission lists**; the only
configuration domain it shares with Claude is **MCP servers**.

This change generalizes the reconciler into `setup-agents`, teaches it to
provision Codex's MCP servers, and removes the Claude sandbox feature (now
unused).

## Goals

- Rename the package `setup-claude-code` → `setup-agents`
  (`pkgs.setup-agents`, `nix run .#setup-agents`).
- Reconcile the shared MCP-server baseline into **both** Claude and Codex.
- Select target agent(s) with `--agent {claude,codex}` (repeatable; default =
  both).
- Add a `codex` home-manager module mirroring `claude-code` (installer-binary
  wrapper + `preStart` + impermanence).
- Enable `codex` on the **helios** host only.
- Remove the Claude sandbox feature end-to-end (flag, merge, config, tests,
  `bubblewrap` dependency).
- Keep the reconciler additive and idempotent: never delete or overwrite user
  edits; re-runs converge to no-ops.

## Non-goals

- Managing Codex's own sandbox (`sandbox_mode`) or approval policy — left at
  Codex defaults.
- Reconciling Codex model / profile / non-MCP settings.
- Auto-installing or updating Claude Code or Codex themselves.
- Creating an OpenAI API-key agenix secret (Codex can auth via `codex login`;
  `preStart` is left empty and can be wired later, host-specific).
- Removing plugins, MCP servers, or settings entries.

## CLI changes — `setup-agents`

New flag:

```
--agent {claude,codex}   Target agent (repeatable). Default: both.
```

Removed flags/behavior:

```
--sandbox                # deleted along with the whole sandbox feature
```

All group flags (`--group`, `--only-group`, `--no-group`, `--all-groups`,
`--no-default-groups`) and domain toggles (`--no-plugins`, `--no-permissions`,
`--no-mcp`, `--enable-plugins`, `--dry-run`) are unchanged. Groups resolve once
and apply to whichever agents are targeted.

### Install-presence gating

- Skip Claude reconciliation if `claude` is not on `PATH`.
- Skip Codex reconciliation if `codex` is not on `PATH`.
- If neither targeted agent is installed, print a notice and exit `0`.

## Reconciliation flow — `main()`

1. Load baked config JSON; resolve selected groups (shared across agents).
2. Determine targeted agents from `--agent` (default: claude + codex).
3. **Claude** (if targeted and installed):
   - plugins → `claude plugin marketplace add` / `claude plugin install`
   - permissions → union-merge into `~/.claude/settings.json`
   - mcp → `claude mcp add-json -s user`
4. **Codex** (if targeted and installed):
   - mcp → `codex mcp add …` (see below)
5. Global `postInstall` snippet runs once (agent-independent).

Return code is the bitwise-or of per-step failure flags, as today.

## Codex MCP reconciliation

Mirrors the Claude MCP path — *query the tool's own CLI for what already exists,
then mutate via the tool's own CLI* — so we never hand-edit user TOML. Verified
against `codex-cli 0.92.0`.

- **Existing set:** `codex mcp list --json` prints a JSON **array** of
  `{"name", "enabled", "transport": {…}, …}`; empty state prints `[]`. The
  existing set is `{entry["name"] for entry in json.loads(stdout or "[]")}` —
  the same `json.loads(… or "[]")` guard used by `_list_installed_plugins`.
- **Add missing:** for each desired server not already present, invoke via a new
  `_run_codex(args)` helper (twin of `_run_claude`). Verified `add` grammar:

  ```
  codex mcp add [OPTIONS] <NAME> (--url <URL> | -- <COMMAND>...)
  ```

  Mapping from the shared MCP spec `{type, command, args, env, url}`:
  - **stdio** (`type: "stdio"` or absent, with a `command`):
    `codex mcp add <name> [--env KEY=VALUE ...] -- <command> [args...]`.
    `--env` is repeatable and, per `--help`, valid only for stdio servers.
  - **http** (spec has `url`): `codex mcp add <name> --url <url>`.
  - Any spec matching neither shape is **warned and skipped** (logged, not a
    silent drop). All current specs are stdio.
- **Idempotent / additive:** already-present servers (by name) are skipped;
  nothing is removed or rewritten. `codex mcp add` on success prints
  `Added global MCP server '<name>'.` and exits 0; a non-zero exit is counted as
  a failure via `check=True`, like `_run_claude`.
- `--dry-run` prints the planned `codex mcp add` lines without executing.

Config is written by codex itself to `~/.codex/config.toml`; the reconciler
never reads or writes that file directly, so no TOML parser is needed.

### New / changed functions

- `_run_codex(args, capture=True, check=True)` — run `codex <args…>`.
- `list_codex_mcp_servers()` — parse `codex mcp list --json` → set of names.
- `codex_add_args(name, spec)` — build the `["mcp","add",…]` argv from a spec
  (pure, unit-testable); returns `None` for unsupported specs.
- `reconcile_codex_mcp(desired, dry_run)` — list existing, add-missing loop
  returning a failure count.

`collect_desired_mcp()` is reused unchanged (shared spec → `{name: (spec,
postInstall)}`). A server's `postInstall` snippet runs after a successful Codex
add, same as on the Claude path.

## Config surface — `packages/setup-agents/default.nix`

Remove the entire `sandbox = { … }` block. Retained keys: `defaultGroups`,
`postInstall`, `plugins`, `permissions`, `mcp`. The `mcp` groups feed both
agents. `package.nix` drops the `sandbox` argument and renames the wrapped
binary to `setup-agents`.

## Sandbox removal (Claude)

- Script: delete `merge_sandbox_into()`, the `--sandbox` arg, and its block in
  `main()`.
- `default.nix` / `package.nix`: delete the `sandbox` option and argument.
- Tests: delete `tests/test_sandbox.py`; drop sandbox assertions elsewhere.
- `modules/home/app/dev/claude-code/default.nix`: remove
  `++ lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.bubblewrap`
  (only needed for the removed sandbox).

## New home module — `modules/home/app/dev/codex/default.nix`

Structural mirror of `claude-code`:

- `codexWrapper` (`writeShellApplication`, name `codex`) that:
  - execs `$HOME/.local/bin/codex` by absolute path;
  - prints an install hint + exits 127 if that binary is missing;
  - runs `${cfg.preStart}` before `exec "$REAL" "$@"`.
- Options `capybara.app.dev.codex`:
  - `enable` (bool, default false);
  - `preStart` (lines, default `""`) — same semantics as claude-code's, for
    agenix-backed secret exports (e.g. `OPENAI_API_KEY`).
- `config = mkIf cfg.enable`:
  - `home.packages = [ codexWrapper ];` (nodejs/python/uv/uv-cache already
    provided by the claude-code module; home-manager dedups when both are
    enabled — codex module stays minimal and does not re-declare them).
  - `capybara.impermanence.directories += [ ".codex" ]`.

## Homes wiring

`homes/x86_64-linux/mtaku3@helios/default.nix`: add under `app.dev`:

```nix
codex = {
  enable = true;
  # preStart left empty; codex authenticates via `codex login`.
};
```

`xanthus` and `darwin` are unchanged.

## Testing

- Existing pytest suite (minus `test_sandbox.py`) continues to pass.
- New `tests/test_codex_mcp.py`:
  - `list_codex_mcp_servers` parses a `codex mcp list --json` array into a name
    set; `[]` / empty stdout → `set()` (mock `_run_codex`).
  - `codex_add_args` builds the right argv: stdio → `mcp add <name> [--env …]
    -- <cmd> <args…>`; url spec → `mcp add <name> --url <url>`; unsupported →
    `None`.
  - `reconcile_codex_mcp` calls `_run_codex(["mcp","add",…])` only for absent
    servers, skips present ones, and is a no-op on a converged list.
  - unsupported spec → warn + skip, no `codex mcp add` call.
  - `--dry-run` performs no `_run_codex` add calls (list may still be queried).
- `--agent` selection: `test_args`/`test_main` gain cases that claude-only vs
  codex-only vs default target the right reconcilers (mock both `_run_claude`
  and `_run_codex`).
- Eval/build: `nix build .#setup-agents` and `nix flake check`.

## Migration notes

- Directory rename `packages/setup-claude-code` → `packages/setup-agents`
  changes the Snowfall-derived package name; any personal `nix run
  .#setup-claude-code` habits become `nix run .#setup-agents`.
- No on-disk config migration: the tool remains additive; existing
  `~/.claude/*` and `~/.codex/config.toml` are read, never rewritten wholesale.
