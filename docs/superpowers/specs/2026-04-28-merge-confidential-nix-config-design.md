# Merge confidential-nix-config into nix-config

## Background

Two nix-config repos exist:

- `~/Workspaces/nix-config` — public, GitHub `mtaku3/nix-config`, source of truth.
- `~/Workspaces/confidential-nix-config` — private, GitHub `mtaku3/confidential-nix-config`, a stale fork of public plus a corporate darwin host.

The corporate PC currently rebuilds from the confidential repo, but the company now prohibits pulling private repos on corporate machines. The confidential repo's content is not actually sensitive, so the resolution is to merge it into the public repo and retire the private one.

A diff audit confirmed that almost every module difference is the result of public moving ahead (new options, refactors, tailscale→netbird swap, native claude-code installer, etc.) rather than corporate-specific changes. Public is correct; confidential is simply behind.

## Goal

Make `nix-config#TMEN0081` build and switch on the corporate Mac, then archive the confidential repo.

## Scope

Bring over **only what TMEN0081 needs**.

### In

1. New flake input: `darwin = { url = "github:lnl7/nix-darwin/nix-darwin-25.11"; inputs.nixpkgs.follows = "nixpkgs"; };`
2. `systems/aarch64-darwin/TMEN0081/default.nix` (host config).
3. `homes/aarch64-darwin/usr0200797@TMEN0081/default.nix` (home config).
4. Darwin modules referenced by TMEN, split per the project's "no needless modularization" rule:
   - **Kept as modules** (reusable darwin abstractions):
     - `modules/darwin/windowManager/aerospace/` (incl. `autoraise.nix`)
     - `modules/darwin/system/fonts/`
     - `modules/darwin/app/dev/docker/`
     - `modules/darwin/app/dev/zsh/`
   - **Inlined into TMEN0081's `default.nix`** (single-host, one-package installs):
     - `vivaldi`, `postman`, `sequel-ace`, `ukelele`

### Out

- `kubecerts`, `mcp-servers-nix` flake inputs (TMEN does not use them).
- All confidential-side variants of public modules (claude-code, git, gpg, kube-cli, tmux, kitty, agenix, docker, kubernetes/*, ssh, suites). Public versions stand.
- `m5p01` and `xanthus` host configs from confidential — public versions stay authoritative.
- Migrating the `secrets` submodule (both repos already share `mtaku3/nix-config-secrets`).
- Preserving git history from confidential (single squash commit; blame for inlined files starts fresh).

## Approach

Work on a feature branch off `main`.

### Step 1 — flake input

Add `darwin` to `flake.nix` inputs alongside `home-manager`, following the existing release-branch pattern.

### Step 2 — copy darwin modules

Copy the four kept darwin module directories verbatim from confidential:

```
modules/darwin/windowManager/aerospace/{default.nix,autoraise.nix}
modules/darwin/system/fonts/default.nix
modules/darwin/app/dev/docker/default.nix
modules/darwin/app/dev/zsh/default.nix
```

### Step 3 — system config for TMEN0081

Create `systems/aarch64-darwin/TMEN0081/{default.nix,keyboard.nix,symbolichotkeys2nix.py}`. Start from confidential's version, then inline the four single-host darwin apps so we don't drag in their module wrappers:

- Replace `capybara.app.desktop.vivaldi = enabled;` with a direct `homebrew.casks` (or `environment.systemPackages`) entry — match whatever the original `vivaldi/default.nix` did.
- Same for `postman`, `sequel-ace`, `ukelele`.

Keep `capybara.app.dev.docker`, `capybara.system.fonts`, `capybara.windowManager.aerospace` as module references.

### Step 4 — home config for TMEN0081

Copy `homes/aarch64-darwin/usr0200797@TMEN0081/default.nix` verbatim. It only references shared `modules/home/*` modules (`kitty`, `zsh`, `neovim`, `git`, `gpg`, `gh`, `tmux`, `devbox`, `claude-code`).

### Step 5 — verify on the corporate Mac

The build can only be validated on darwin hardware. On TMEN0081:

1. `nix flake check` (will exercise both nixos and darwin attrs).
2. `darwin-rebuild build --flake .#TMEN0081`.
3. Iterate on any darwin-incompat issue in the shared `modules/home/*` modules. Preferred fix: make the shared module darwin-clean (e.g., guard linux-only paths with `lib.mkIf pkgs.stdenv.isLinux` or use `config.home.homeDirectory`). Avoid forking modules.
4. `darwin-rebuild switch --flake .#TMEN0081`.

### Step 6 — retire confidential repo

Once the corporate PC is running off public:

- Push the merge branch, open PR, merge to `main`.
- Update the corporate PC's checkout to point at `mtaku3/nix-config`.
- Archive `mtaku3/confidential-nix-config` on GitHub (do not delete — keeps history accessible).

## Risks and mitigations

- **Shared home modules may not be darwin-clean.** Modules like `kitty`, `tmux`, `git`, `gpg`, `claude-code` were written and tested on linux. Mitigation: `darwin-rebuild build` is the gate; fix incompatibilities in-module rather than forking.
- **`capybara.impermanence` references on darwin.** Several home modules (e.g., `gpg`, `claude-code`) call `capybara.impermanence.directories`. The TMEN home config doesn't enable impermanence, so the option must accept being set without impermanence enabled — verify this isn't asserted anywhere. If it is, relax the assertion to `mkIf` on impermanence.enable.
- **Snowfall auto-discovery of `modules/darwin/`.** Snowfall should pick this up automatically once the `darwin` input is present; if not, may need a small `lib.mkFlake` adjustment. Surface during `nix flake check`.

## Acceptance

- `nix flake check` passes.
- `darwin-rebuild switch --flake .#TMEN0081` succeeds on the corporate Mac.
- All previously working hosts (`helios`, `m5p01`, `xanthus`) still evaluate (`nix flake check` covers this).
- Confidential repo archived; corporate PC pulls from public only.
