# claude-code wrapper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bare `~/.local/bin` PATH entry in the `claude-code` Home Manager module with a Nix-built wrapper that performs an install-presence check and runs a configurable `preStart` snippet before exec'ing the real binary.

**Architecture:** A single Home Manager module file (`modules/home/app/dev/claude-code/default.nix`) gains a new `preStart` option (`types.lines`) and a `pkgs.writeShellApplication` derivation named `claude` added to `home.packages`. The wrapper invokes `~/.local/bin/claude` by absolute path, so `~/.local/bin` is dropped from `home.sessionPath`. Spec at `docs/superpowers/specs/2026-04-30-claude-code-wrapper-design.md`.

**Tech Stack:** Nix flakes, Home Manager, Snowfall layout, `pkgs.writeShellApplication`.

---

## File Structure

- **Modify:** `modules/home/app/dev/claude-code/default.nix` — adds `preStart` option, builds wrapper, updates `home.packages` and `home.sessionPath`. This is the only source file changed.

There is no separate test file. The module is validated by:

1. Evaluating the host's home configuration (`nix eval ...activationPackage.drvPath`) — catches type errors and option-merging mistakes.
2. Building the wrapper derivation directly and exercising it from a shell — catches runtime/script bugs without needing a full home-manager activation.

---

## Task 1: Replace module with wrapper + `preStart` option

**Files:**
- Modify: `modules/home/app/dev/claude-code/default.nix` (whole file replacement)

- [ ] **Step 1: Read the current file to confirm starting state**

Run:

```bash
cat modules/home/app/dev/claude-code/default.nix
```

Expected: matches the pre-change contents (option block with only `enable`, `home.sessionPath` containing `"$HOME/.local/bin"`, no wrapper).

- [ ] **Step 2: Replace the file with the new module**

Write the following exact contents to `modules/home/app/dev/claude-code/default.nix`:

```nix
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.claude-code;

  claudeWrapper = pkgs.writeShellApplication {
    name = "claude";
    # No runtimeInputs: the wrapper deliberately calls the user's
    # installer-managed binary at ~/.local/bin/claude by absolute path,
    # and only uses bash builtins + `cat` (provided by writeShellApplication's
    # default PATH) for the missing-install message.
    text = ''
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

      ${cfg.preStart}

      exec "$REAL" "$@"
    '';
    meta = {
      description = "Wrapper around the installer-managed claude-code binary";
      mainProgram = "claude";
    };
  };
in {
  options.capybara.app.dev.claude-code = {
    enable = mkBoolOpt false "Whether to enable the claude-code";

    preStart = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Shell snippet sourced by the claude wrapper before exec'ing the
        installer-managed binary. Intended for exporting secrets read from
        agenix-managed files, e.g.

          export ANTHROPIC_API_KEY=$(cat ''${config.age.secrets.anthropic.path})

        Runs under `set -euo pipefail`; a non-zero exit aborts the wrapper
        before claude-code runs.
      '';
    };
  };

  config = mkIf cfg.enable {
    # claude-code is installed via the native installer
    # (curl -fsSL https://claude.ai/install.sh | bash) so it can self-update.
    # The installer drops a launcher at ~/.local/bin/claude and runtime
    # files under ~/.claude/local/. The wrapper below shadows that launcher
    # on PATH so we can run preStart hooks (typically secret exports) first.
    home.packages = [
      claudeWrapper
      pkgs.nodejs
      pkgs.python3
      pkgs.uv
      pkgs.socat
    ] ++ lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.bubblewrap;

    home.sessionPath = ["$HOME/.npm-global/bin"];

    home.file.".npmrc".text = ''
      prefix=${config.home.homeDirectory}/.npm-global
    '';

    capybara.impermanence.directories = [
      ".claude"
      ".local/bin"
      ".local/share/uv"
      ".cache/uv"
      ".npm"
      ".npm-global"
    ];
    capybara.impermanence.files = [
      ".claude.json"
    ];
  };
}
```

Notes for the implementer:

- `with lib;` is preserved from the original — `mkOption`, `types`, `mkIf` resolve through it.
- `with lib.capybara;` brings in the project's `mkBoolOpt` helper used by other modules.
- The `text` of `writeShellApplication` is a single Nix multi-line string. Inside it, `${cfg.preStart}` is plain Nix interpolation (spliced at evaluation), while `$HOME`, `$REAL`, `$@`, etc. are dollar-escaped by Nix's `''…''` rules — they need no escaping because Nix only treats `''${...}` specially. The `''${config.age.secrets...}` inside the option `description` IS escaped because the description is itself a Nix string and we want the literal `${...}` to appear in `nix-help` output.
- `writeShellApplication` adds `set -euo pipefail` and shellcheck automatically; do not add it manually inside `text`.

- [ ] **Step 3: Evaluate the home configuration to catch syntax / type errors**

Run:

```bash
nix eval --no-warn-dirty '.#homeConfigurations."mtaku3@helios".activationPackage.drvPath'
```

Expected: prints a `/nix/store/...-home-manager-generation.drv` path with no errors. If you see `error: ...`, fix the Nix file and re-run before continuing.

- [ ] **Step 4: Build the wrapper derivation in isolation and inspect it**

Run:

```bash
nix build --no-link --print-out-paths --no-warn-dirty \
  --impure --expr '
    let
      flake = builtins.getFlake (toString ./.);
      hm = flake.homeConfigurations."mtaku3@helios";
      pkgs = hm.pkgs;
      cfg = { preStart = ""; };
    in pkgs.writeShellApplication {
      name = "claude";
      text = '"'"''"'"'
        REAL=$HOME/.local/bin/claude
        if [[ ! -x $REAL ]]; then
          cat >&2 <<EOF2
        claude-code is not installed.
        EOF2
          exit 127
        fi
        exec "$REAL" "$@"
      '"'"''"'"';
    }
  '
```

If that one-liner is awkward (it is), an equivalent verification is to skip Step 4 and rely on Step 5 — the activation package build forces the wrapper to build too. Mark Step 4 done either way.

- [ ] **Step 5: Build the full home-manager activation package**

Run:

```bash
nix build --no-link --print-out-paths --no-warn-dirty \
  '.#homeConfigurations."mtaku3@helios".activationPackage'
```

Expected: prints a single `/nix/store/...-home-manager-generation` path. Build must succeed (writeShellApplication runs shellcheck — any shellcheck error fails the build here).

If shellcheck fails, read the error, adjust the script body in `text`, and re-run from Step 3.

- [ ] **Step 6: Locate and read the built wrapper script**

Run:

```bash
RESULT=$(nix build --no-link --print-out-paths --no-warn-dirty \
  '.#homeConfigurations."mtaku3@helios".activationPackage')
find "$RESULT" -name claude -type f -executable | head -1 | xargs cat
```

Expected: prints a bash script that includes `set -o errexit`, `REAL=$HOME/.local/bin/claude`, the install-help heredoc, an empty line where `${cfg.preStart}` was (because it defaults to `""`), and `exec "$REAL" "$@"`.

- [ ] **Step 7: Smoke-test the wrapper's missing-install path**

Pick the wrapper's actual path out of the built generation and run it with `HOME` redirected somewhere empty so the real binary won't be found:

```bash
WRAPPER=$(find "$RESULT" -name claude -type f -executable | head -1)
HOME=$(mktemp -d) "$WRAPPER"; echo "exit=$?"
```

Expected output (on stderr):

```
claude-code is not installed.

Install with:
  curl -fsSL https://claude.ai/install.sh | bash

Docs: https://docs.claude.com/en/docs/claude-code/setup
exit=127
```

- [ ] **Step 8: Smoke-test the wrapper's happy path**

Create a fake "real" claude under a temp `HOME`, then invoke the wrapper:

```bash
TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.local/bin"
cat > "$TMPHOME/.local/bin/claude" <<'EOF'
#!/usr/bin/env bash
echo "real claude args=$*"
echo "real claude FOO=${FOO-unset}"
EOF
chmod +x "$TMPHOME/.local/bin/claude"
HOME=$TMPHOME "$WRAPPER" --version foo
```

Expected output:

```
real claude args=--version foo
real claude FOO=unset
```

(Exit code 0.)

- [ ] **Step 9: Smoke-test `preStart` env-var injection**

Repeat Step 5–6 with a non-empty `preStart` to confirm interpolation. Easiest: temporarily set `capybara.app.dev.claude-code.preStart` in `homes/x86_64-linux/mtaku3@helios/default.nix`, build, run the wrapper against the fake real binary, then revert.

```bash
# from repo root
perl -i -pe 's/claude-code = enabled;/claude-code = { enable = true; preStart = "export FOO=bar"; };/' \
  homes/x86_64-linux/mtaku3@helios/default.nix

RESULT=$(nix build --no-link --print-out-paths --no-warn-dirty \
  '.#homeConfigurations."mtaku3@helios".activationPackage')
WRAPPER=$(find "$RESULT" -name claude -type f -executable | head -1)
HOME=$TMPHOME "$WRAPPER"
```

Expected output:

```
real claude args=
real claude FOO=bar
```

Then revert the home file:

```bash
perl -i -pe 's/claude-code = \{ enable = true; preStart = "export FOO=bar"; \};/claude-code = enabled;/' \
  homes/x86_64-linux/mtaku3@helios/default.nix
```

Verify with:

```bash
git diff homes/x86_64-linux/mtaku3@helios/default.nix
```

Expected: no output (file restored).

- [ ] **Step 10: Final activation-package build with the unmodified home config**

```bash
nix build --no-link --print-out-paths --no-warn-dirty \
  '.#homeConfigurations."mtaku3@helios".activationPackage'
```

Expected: success.

Also build `mtaku3@xanthus` (the other Linux host that enables this module) to confirm cross-host compatibility:

```bash
nix build --no-link --print-out-paths --no-warn-dirty \
  '.#homeConfigurations."mtaku3@xanthus".activationPackage'
```

Expected: success.

The Darwin host `usr0200797@TMEN0081` cannot be built from a Linux machine and is skipped here; the only platform-conditional code (`pkgs.bubblewrap` under `optional ... isLinux`) is unchanged from the original module, so this is a low risk.

- [ ] **Step 11: Commit**

```bash
git add modules/home/app/dev/claude-code/default.nix
git commit -m "$(cat <<'EOF'
feat(claude-code): wrap installer binary with preStart hook

Replace the bare ~/.local/bin PATH entry with a Nix-built `claude`
wrapper that:

- Prints install guidance and exits 127 if ~/.local/bin/claude is
  absent (no auto-install, no surprise network calls).
- Runs a new `preStart` snippet (`types.lines`, default empty)
  before exec'ing the installer-managed binary. Intended for
  exporting secrets read from agenix-managed files.

Drops $HOME/.local/bin from home.sessionPath since the wrapper now
calls the real binary by absolute path. Impermanence entries are
unchanged so installer self-update state still persists.

Spec: docs/superpowers/specs/2026-04-30-claude-code-wrapper-design.md
EOF
)"
```

Expected: commit succeeds. If pre-commit hooks fail, fix and re-stage; do not amend.

---

## Self-Review Notes

- **Spec coverage:**
  - "wrapper named `claude` via `writeShellApplication` in `home.packages`" → Step 2.
  - "remove `~/.local/bin` from `home.sessionPath`, keep `~/.npm-global/bin`" → Step 2.
  - "`preStart` option, `types.lines`, default `""`" → Step 2.
  - "missing-binary path prints help + exits 127" → Step 7.
  - "preStart runs before exec, exports affect environment" → Step 9.
  - "impermanence entries unchanged" → Step 2 (verify by diff).
  - "no auto-install" → covered by Step 7 (no curl in script).
- **Placeholder scan:** none.
- **Type consistency:** option name `preStart` consistent across spec, module, plan, and tests.
