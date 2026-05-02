# `setup-claude-code` package design

## Context

`claude-code` is installed via the upstream installer (`curl … | bash`),
which manages updates itself but leaves *configuration* — installed plugins,
permission rules, sandbox policy, MCP servers — entirely up to the user. The
existing home-manager module (`modules/home/app/dev/claude-code/default.nix`)
only wraps the installer binary so a `preStart` snippet can run; it does not
provision configuration.

This package adds a runnable command, `setup-claude-code`, that brings a
freshly-installed Claude Code in line with a Nix-declared baseline: install
missing plugins, register their marketplaces, add MCP servers, and union-merge
permission/sandbox rules into the appropriate config files. It is invoked by
hand. Re-running is safe and additive — never overwrites user edits, never
uninstalls.

## Goals

- A flake-exported package: `pkgs.setup-claude-code`.
- Declarative baseline: plugins, permissions, sandbox, and MCP servers defined
  in Nix.
- Group-based selection (uv-style flags): `--group`, `--only-group`,
  `--no-group`, `--all-groups`, `--no-default-groups`.
- Sandbox is opt-in only via `--sandbox`.
- Idempotent: re-runs are no-ops once converged.
- Additive: never deletes plugins, MCP servers, or settings entries.

## Non-goals

- Auto-installing or updating Claude Code itself.
- Removing plugins, MCP servers, or settings entries.
- Wiring `setup-claude-code` into the existing `claude` wrapper's `preStart`.
- A state/manifest sidecar file. Truth lives in `~/.claude/settings.json`,
  `~/.claude.json`, and `claude plugin/mcp …` queries.

## Config files this package touches

Two on-disk files are involved. Schema fields used here come from the
canonical schema at <https://www.schemastore.org/claude-code-settings.json>
(for `settings.json`) and from observation of `~/.claude.json` (which has no
public schema).

### `~/.claude/settings.json` — direct atomic write

Keys we read and union-merge:

```jsonc
{
  "permissions": {
    "allow": [ "<rule-pattern>", ... ],
    "deny":  [ "<rule-pattern>", ... ],
    "ask":   [ "<rule-pattern>", ... ]
    // other permissions.* keys (defaultMode, additionalDirectories, ...) untouched
  },
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": [ "<glob>", ... ],
      "denyWrite":  [ "<glob>", ... ]
      // other filesystem.* keys (allowRead/denyRead) addable later via opts
    }
    // sandbox.network.* not managed in v1
  }
}
```

`enabledPlugins` is also a key in this file but is set by Claude itself when
`claude plugin install` runs. We never write it directly.

### `~/.claude.json` — read-only

We read `mcpServers` for an existence check only; mutations go through
`claude mcp add-json -s user`. Observed entry shape (stdio server):

```jsonc
{
  "mcpServers": {
    "<name>": {
      "type": "stdio",
      "command": "<executable>",
      "args": [ "<arg>", ... ],
      "env":  { "<KEY>": "<value>", ... }
    }
  }
}
```

HTTP / SSE servers carry different fields (`type: "http"`, `url`, `headers`).
The Nix `opts.mcp.<group>.<name>` attrs are passed through `json.dumps` to
`claude mcp add-json`, so any shape Claude accepts is supported by adding the
right keys in `opts`.

## Architecture

```
packages/setup-claude-code/
  default.nix              # opts (data) + callPackage ./package.nix opts
  package.nix              # builder
  setup-claude-code.py     # single-file stdlib Python script
```

`flake.nix` exports `packages.<system>.setup-claude-code`. The home module
just adds it to `home.packages`; no `preStart` wiring.

### `default.nix` — opts (data)

```nix
{ pkgs, ... }:
let
  opts = {
    # Group names that are default-on. Applied to whichever of plugins /
    # permissions / mcp define them; silently skipped elsewhere. There is
    # no magic "default" group name — anything listed here counts.
    defaultGroups = [ "default" ];

    plugins = {
      default = [
        { plugin = "superpowers";    marketplace = "anthropics/claude-plugins-official"; }
      ];
      research = [
        { plugin = "deep-research";  marketplace = "obra/superpowers-marketplace"; }
      ];
    };

    permissions = {
      default = {
        allow = [ "Read(*)" ];
        deny  = [ "Write(/mnt/t4/**)" "Write(/mnt/miubiq-fs/**)" ];
        ask   = [ "Bash(git push*)" ];
      };
      research = { allow = [ "WebFetch" ]; };
    };

    # Flat (no groups). Opt-in via --sandbox. Keys mirror the schema.
    sandbox = {
      filesystem = {
        allowWrite = [ "~/.cache/**" "~/Workspaces/**" ];
        denyWrite  = [ "/mnt/t4/**" "/mnt/miubiq-fs/**" ];
      };
    };

    mcp = {
      default = {
        # name -> spec passed verbatim to `claude mcp add-json <name> <json> -s user`
        paper-search-mcp = {
          type    = "stdio";
          command = "uvx";
          args    = [ "--from" "paper-search-mcp" "python" "-m" "paper_search_mcp.server" ];
          env     = {};
        };
      };
    };
  };
in
  pkgs.callPackage ./package.nix opts
```

### `package.nix` — builder

```nix
{ python3, formats, runCommand, makeWrapper,
  defaultGroups, plugins, permissions, sandbox, mcp }:
let
  configFile = (formats.json {}).generate "setup-claude-code.json"
                 { inherit defaultGroups plugins permissions sandbox mcp; };
in
runCommand "setup-claude-code" {
  nativeBuildInputs = [ makeWrapper ];
} ''
  mkdir -p $out/bin
  makeWrapper ${python3}/bin/python3 $out/bin/setup-claude-code \
    --add-flags "${./setup-claude-code.py} --config ${configFile}"
''
```

- Config is a real, inspectable JSON file in `/nix/store`.
- Python script lives at its own store path via `${./setup-claude-code.py}`;
  no copy step.
- Standard library only — no PyPI deps, no `buildPythonApplication`.
- Runtime requirements: `python3` and `claude` on PATH. No `jq` (Python
  handles JSON natively).

## CLI

```
setup-claude-code [flags]

Group selection (uv-style; applies independently to plugins, permissions, mcp):
  --group NAME              include group (repeatable)
  --only-group NAME         only this group; suppresses default (repeatable)
  --no-group NAME           exclude group (repeatable)
  --all-groups              include every defined group
  --no-default-groups       drop the default group

Domain toggles (default: all on except sandbox):
  --sandbox                 opt-in: write sandbox.* to settings.json
  --no-plugins
  --no-permissions
  --no-mcp

Other:
  --dry-run                 print planned `claude` commands and a settings.json
                            diff; no writes
  --config PATH             path to config JSON (default supplied by Nix wrapper)
```

### Group resolution rules

There is no magic group name. The set of "default-on" groups is whatever
`opts.defaultGroups` lists in `default.nix`. Resolution runs once globally
to produce a selected set of group names, then is intersected with each
domain's defined groups.

1. Start set = `set(opts.defaultGroups)`.
2. `--no-default-groups` clears the start set.
3. `--only-group X` sets the start set to `{X}` (and thus implies
   `--no-default-groups`).
4. `--group X` adds X (repeatable; any prior `--only-group` is preserved as
   the base it was added to).
5. `--no-group X` removes X.
6. `--all-groups` overrides everything to the union of all groups defined
   across all three domains.
7. Unknown group names → exit 2 with an error listing the known groups across
   domains. (A name is "known" iff at least one domain defines it. A name
   listed in `opts.defaultGroups` that no domain defines is also an error,
   detected at startup.)

For each domain independently, the applied set is
`selected ∩ defined-groups-in-domain`. A group name that exists in some
domains but not others is silently skipped in the domains where it is
undefined (e.g. `research` is fine even though `mcp` has no `research`
group).

## Reconcile semantics

All operations are **additive**. Nothing is ever uninstalled, removed, or
overwritten.

### Preflight

- `shutil.which("claude")` returns `None` → print "claude-code not installed"
  to stderr, exit 0.
- `~/.claude/settings.json` missing → treat as `{}`; create on first write.
- `~/.claude/settings.json` invalid JSON → exit 2, no writes.
- `~/.claude.json` missing or invalid → treat `mcpServers` as empty; do not
  error (this file is owned by Claude, not us).

### plugins (skipped under `--no-plugins`)

1. Compute desired set: union of `(plugin, marketplace_source)` across
   selected plugin groups.
2. `claude plugin marketplace list --json` → list of
   `{name, source, repo, ...}`. Build a map from a normalized source key
   (for `source == "github"`: the `repo` field; for URL/path sources: the
   corresponding key) to `name`.
3. For each desired marketplace `<source>` not in the map:
   `claude plugin marketplace add <source>`. Re-query
   `marketplace list --json` to learn its registered name.
4. `claude plugin list --json` → set of installed ids
   (`<plugin>@<registered-name>`).
5. For each desired plugin not installed:
   `claude plugin install <plugin>@<registered-name>`.
6. `claude plugin install` is responsible for setting `enabledPlugins` in
   `settings.json`; we do not write this key directly.

### permissions (skipped under `--no-permissions`)

1. Compute desired lists: for each of `allow`, `deny`, `ask`, union across
   selected permission groups.
2. Read `~/.claude/settings.json`.
3. For each list field: `final = unique(current ∪ desired)`, preserving order
   with current entries first.
4. Atomic write: `json.dump` to a temp file in `~/.claude/`, then `os.replace`.

### sandbox (only under `--sandbox`)

1. Read settings.
2. `settings["sandbox"]["enabled"] = True`.
3. For `sandbox.filesystem.allowWrite` and `sandbox.filesystem.denyWrite`:
   `final = unique(current ∪ desired)`.
4. Other sandbox keys (`network.*`, `autoAllowBashIfSandboxed`, etc.) are not
   managed in v1; they can be added to `opts.sandbox` later and projected via
   the same union/assignment pattern.
5. Atomic write.

### mcp (skipped under `--no-mcp`)

1. Compute desired map: `{name: spec}` union across selected mcp groups
   (collisions on name across groups → exit 2).
2. Read `~/.claude.json`; let `existing = data.get("mcpServers", {})`.
3. For each desired `(name, spec)`:
   - `name in existing` → skip.
   - else → `claude mcp add-json <name> <json.dumps(spec)> -s user`.
4. Never overwrite. Never write `~/.claude.json` ourselves.

## Errors and exit codes

| Code | Condition |
|------|-----------|
| 0    | All operations succeeded, or claude not installed (warned). |
| 1    | One or more `claude plugin install` / `mcp add-json` failed; others continued. |
| 2    | Bad usage (unknown group, MCP-name collision) or unrecoverable input (invalid `settings.json`). |

`--dry-run` short-circuits before any subprocess call that mutates state and
before any settings.json write; instead it prints the planned `claude …`
commands and a unified diff of the would-be `settings.json`.

## Python script structure (single file, ~250 LoC)

Top-down outline of `setup-claude-code.py`:

- `main()` — argparse, dispatch.
- `resolve_groups(domain_groups, args)` — apply uv-style selection rules.
- `reconcile_plugins(desired, dry_run)` — marketplace + install loop.
- `merge_permissions(desired, dry_run)` — settings.json union-merge for
  `allow/deny/ask`.
- `apply_sandbox(desired, dry_run)` — settings.json sandbox merge.
- `reconcile_mcp(desired, dry_run)` — read `~/.claude.json`,
  `mcp add-json` for missing entries.
- `load_settings()` / `save_settings(obj)` — JSON IO with atomic write
  for `~/.claude/settings.json`.
- `read_claude_json()` — best-effort JSON read of `~/.claude.json`,
  returning `{}` on error.
- `claude(*args, capture=False, check=True)` — subprocess wrapper.
- `eprint(...)`, `info(...)`, `warn(...)` — stderr output helpers.

## Testing

Manual smoke tests at plan time:

- Fresh `~/.claude/`: `setup-claude-code --dry-run` prints expected actions.
- Fresh `~/.claude/`: `setup-claude-code` then re-run; second run is a no-op.
- `--group research` adds research-only plugins/permissions; default group
  still applied.
- `--only-group research` adds only research; default suppressed.
- `--sandbox` writes the sandbox block; without it, sandbox is untouched.
- User-added entry in `permissions.allow` survives a re-run.
- `claude` not on PATH: warns, exits 0.
- Corrupt `settings.json`: exits 2, no writes.

(No automated test suite in v1 — script is small enough to verify by hand.
Tests can be added later as Python `unittest` if scope grows.)

## Open items deferred to plan

- **Marketplace source-→name mapping detail.** `marketplace list --json` has
  `source` (`"github"`, `"url"`, …) plus a corresponding key (`repo`, `url`,
  …). Confirm at plan time by registering one URL-shaped and one path-shaped
  source and inspecting the resulting JSON.
- **`claude mcp add-json` field coverage.** Confirm by experiment that
  passing `{"type": "stdio", "command": "...", "args": [...], "env": {...}}`
  round-trips into `~/.claude.json` exactly. Add HTTP/SSE shape to the spec
  examples once verified.
- **`pkgs.formats.json {}` shape acceptance.** Sanity-check that the version
  pinned in this flake accepts arbitrarily-nested attrsets without
  RFC-42-style typecheck failures.

## Migration

None. New package; nothing else changes. Users opt in by adding
`pkgs.setup-claude-code` to their `home.packages` and running it once.
