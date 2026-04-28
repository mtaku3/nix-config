# Merge confidential-nix-config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge the corporate-Mac portion of `~/Workspaces/confidential-nix-config` into `~/Workspaces/nix-config` so the corporate PC can rebuild from the public repo.

**Architecture:** Add `nix-darwin` as a flake input. Bring over the `TMEN0081` host (system + home) and the four reusable darwin modules (aerospace, fonts, docker, zsh). Inline the four single-host darwin app modules (vivaldi, postman, sequel-ace, ukelele) directly into the host config per the project's "no needless modularization" rule. Public modules and the `m5p01`/`xanthus`/`helios` hosts are untouched.

**Tech Stack:** Nix flakes, snowfall-lib, nix-darwin, home-manager.

**Validation:** No unit tests apply — the gates are `nix flake check` (evaluation) and `darwin-rebuild build --flake .#TMEN0081` (build), the latter only runnable on the corporate Mac.

---

## File Structure

**Created:**
- `modules/darwin/windowManager/aerospace/default.nix`
- `modules/darwin/windowManager/aerospace/autoraise.nix`
- `modules/darwin/system/fonts/default.nix`
- `modules/darwin/app/dev/docker/default.nix`
- `modules/darwin/app/dev/zsh/default.nix`
- `systems/aarch64-darwin/TMEN0081/default.nix`
- `systems/aarch64-darwin/TMEN0081/keyboard.nix`
- `systems/aarch64-darwin/TMEN0081/symbolichotkeys2nix.py`
- `homes/aarch64-darwin/usr0200797@TMEN0081/default.nix`

**Modified:**
- `flake.nix` — add `darwin` input.

---

## Task 1: Add nix-darwin flake input

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Edit `flake.nix` to add the `darwin` input**

Insert after the `home-manager` input block (currently lines covering `home-manager = { url = ...; inputs.nixpkgs.follows = "nixpkgs"; };`):

```nix
    darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

- [ ] **Step 2: Verify the flake still evaluates**

Run: `nix flake check --no-build`
Expected: PASS (no new systems yet, just the input addition).

- [ ] **Step 3: Commit**

```bash
git add flake.nix flake.lock
git commit -m "feat(flake): add nix-darwin input for darwin host support"
```

---

## Task 2: Add reusable darwin modules

**Files:**
- Create: `modules/darwin/windowManager/aerospace/default.nix`
- Create: `modules/darwin/windowManager/aerospace/autoraise.nix`
- Create: `modules/darwin/system/fonts/default.nix`
- Create: `modules/darwin/app/dev/docker/default.nix`
- Create: `modules/darwin/app/dev/zsh/default.nix`

These modules come verbatim from `~/Workspaces/confidential-nix-config`. None of them are tweaked.

- [ ] **Step 1: Create `modules/darwin/windowManager/aerospace/default.nix`**

```nix
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.windowManager.aerospace;
in {
  options.capybara.windowManager.aerospace = {
    enable = mkBoolOpt false "Whether to enable the aerospace";
  };

  imports = [./autoraise.nix];

  config = mkIf cfg.enable {
    services.aerospace = let
      aerospace = pkgs.aerospace;
    in {
      enable = true;
      package = aerospace;
      settings = {
        default-root-container-layout = "tiles";
        default-root-container-orientation = "horizontal";
        on-focus-changed = ["move-mouse window-lazy-center"];
        exec-on-workspace-change = ["/usr/bin/env" "bash" "-c" "${aerospace}/bin/aerospace move-mouse window-lazy-center"];
        workspace-to-monitor-force-assignment = {
          "1" = "main";
          "2" = "main";
          "3" = "main";
          "4" = "main";
          "5" = "main";
          "6" = "main";
          "7" = "main";
          "8" = "main";
          "9" = "main";
          "10" = "main";
          "11" = 1;
          "12" = 3;
        };
        mode.main.binding = {
          alt-enter = "exec-and-forget open -n -a kitty";
          alt-b = "exec-and-forget open -n -a vivaldi";
          alt-shift-q = "close --quit-if-last-window";
          alt-j = "focus --ignore-floating left";
          alt-k = "focus --ignore-floating right";
          alt-h = "focus-monitor prev";
          alt-l = "focus-monitor next";
          alt-shift-j = "move left";
          alt-shift-k = "move right";
          alt-shift-h = "move-node-to-monitor --focus-follows-window prev";
          alt-shift-l = "move-node-to-monitor --focus-follows-window next";
          alt-f = "fullscreen";
          alt-1 = "workspace 1";
          alt-2 = "workspace 2";
          alt-3 = "workspace 3";
          alt-4 = "workspace 4";
          alt-5 = "workspace 5";
          alt-6 = "workspace 6";
          alt-7 = "workspace 7";
          alt-8 = "workspace 8";
          alt-9 = "workspace 9";
          alt-0 = "workspace 10";
          alt-shift-1 = "move-node-to-workspace --focus-follows-window 1";
          alt-shift-2 = "move-node-to-workspace --focus-follows-window 2";
          alt-shift-3 = "move-node-to-workspace --focus-follows-window 3";
          alt-shift-4 = "move-node-to-workspace --focus-follows-window 4";
          alt-shift-5 = "move-node-to-workspace --focus-follows-window 5";
          alt-shift-6 = "move-node-to-workspace --focus-follows-window 6";
          alt-shift-7 = "move-node-to-workspace --focus-follows-window 7";
          alt-shift-8 = "move-node-to-workspace --focus-follows-window 8";
          alt-shift-9 = "move-node-to-workspace --focus-follows-window 9";
          alt-shift-0 = "move-node-to-workspace --focus-follows-window 10";
        };
      };
    };
  };
}
```

- [ ] **Step 2: Create `modules/darwin/windowManager/aerospace/autoraise.nix`**

```nix
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara;
{
  config = let
    package = pkgs.autoraise;
  in {
    environment.systemPackages = [package];

    launchd.user.agents.autoraise.serviceConfig = {
      ProgramArguments = ["${package}/bin/autoraise" "-disableKey" "disabled"];
      KeepAlive = true;
      RunAtLoad = true;
    };
  };
}
```

- [ ] **Step 3: Create `modules/darwin/system/fonts/default.nix`**

```nix
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.system.fonts;
in {
  options.capybara.system.fonts = {
    enable = mkBoolOpt false "Whether to enable the fonts";
  };

  config = mkIf cfg.enable {
    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      nerd-fonts.jetbrains-mono
    ];
  };
}
```

- [ ] **Step 4: Create `modules/darwin/app/dev/docker/default.nix`**

```nix
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.docker;
in {
  options.capybara.app.dev.docker = {
    enable = mkBoolOpt false "Whether to enable the docker";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.homebrew.enable;
        message = "Homebrew has to be enabled to install this";
      }
    ];

    homebrew.brews = ["docker" "colima"];
  };
}
```

- [ ] **Step 5: Create `modules/darwin/app/dev/zsh/default.nix`**

```nix
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  user-names = builtins.attrNames config.snowfallorg.users;
  zshEnabled = any (name: config.home-manager.users.${name}.capybara.app.dev.zsh.enable) user-names;
in {
  config = mkIf zshEnabled {
    environment.etc."zshrc".text = ''
      ${optionalString config.homebrew.enable "eval \"$(${config.homebrew.brewPrefix}/brew shellenv)\""}
    '';
  };
}
```

- [ ] **Step 6: Verify evaluation**

Run: `nix flake check --no-build`
Expected: PASS. Modules exist but are unused (no darwin host yet).

- [ ] **Step 7: Commit**

```bash
git add modules/darwin
git commit -m "feat(darwin): add aerospace, fonts, docker, zsh modules"
```

---

## Task 3: Add TMEN0081 system config

**Files:**
- Create: `systems/aarch64-darwin/TMEN0081/default.nix`
- Create: `systems/aarch64-darwin/TMEN0081/keyboard.nix`
- Create: `systems/aarch64-darwin/TMEN0081/symbolichotkeys2nix.py`

The host config inlines the four single-host homebrew apps (vivaldi, postman, sequel-ace, ukelele) per the project's "no needless modularization" rule. The four modules in confidential each just add one homebrew cask/brew, so they collapse to a single `homebrew.casks` list.

- [ ] **Step 1: Create the host directory**

```bash
mkdir -p systems/aarch64-darwin/TMEN0081
```

- [ ] **Step 2: Create `systems/aarch64-darwin/TMEN0081/default.nix`**

```nix
{lib, ...}:
with lib;
with lib.capybara; {
  imports = [./keyboard.nix];

  config = {
    nix.enable = false;

    homebrew = enabled;
    system.primaryUser = "usr0200797";

    homebrew.casks = [
      "vivaldi"
      "postman"
      "sequel-ace"
      "ukelele"
    ];

    capybara = {
      app.dev.docker = enabled;
      system.fonts = enabled;
      windowManager.aerospace = enabled;
    };

    system = {
      defaults = {
        NSGlobalDomain = {
          AppleInterfaceStyle = "Dark";
          "com.apple.mouse.tapBehavior" = 1;
        };
        dock.autohide = true;
      };
      keyboard = {
        enableKeyMapping = true;
        swapLeftCtrlAndFn = true;
      };
    };

    system.stateVersion = 5;
  };
}
```

- [ ] **Step 3: Copy `keyboard.nix` from confidential repo**

```bash
cp ~/Workspaces/confidential-nix-config/systems/aarch64-darwin/TMEN0081/keyboard.nix \
   systems/aarch64-darwin/TMEN0081/keyboard.nix
```

- [ ] **Step 4: Copy `symbolichotkeys2nix.py` helper**

```bash
cp ~/Workspaces/confidential-nix-config/systems/aarch64-darwin/TMEN0081/symbolichotkeys2nix.py \
   systems/aarch64-darwin/TMEN0081/symbolichotkeys2nix.py
```

- [ ] **Step 5: Verify evaluation**

Run: `nix flake check --no-build --show-trace`
Expected: PASS — `darwinConfigurations.TMEN0081` should now be present (snowfall auto-discovers it). If it fails complaining about missing `darwin` outputs, check Task 1 was applied.

- [ ] **Step 6: Commit**

```bash
git add systems/aarch64-darwin
git commit -m "feat(systems): add TMEN0081 corporate macOS host"
```

---

## Task 4: Add TMEN0081 home config

**Files:**
- Create: `homes/aarch64-darwin/usr0200797@TMEN0081/default.nix`

The home config references shared `modules/home/*` modules; these are linux-developed but are home-manager modules so should work on darwin. Any darwin-incompat issues surface at build time and are addressed in Task 5.

- [ ] **Step 1: Create the home directory**

```bash
mkdir -p homes/aarch64-darwin/usr0200797@TMEN0081
```

- [ ] **Step 2: Create `homes/aarch64-darwin/usr0200797@TMEN0081/default.nix`**

```nix
{lib, ...}:
with lib;
with lib.capybara; {
  capybara = {
    app = {
      desktop = {
        kitty = enabled;
      };
      dev = {
        zsh = enabled;
        neovim = enabled;
        git = {
          enable = true;
          username = "mtaku3";
          email = "me@mtaku3.com";
          signingKey = "EA7E68BE661AE1D8";
          signByDefault = true;
        };
        gpg = enabled;
        gh = enabled;
        tmux = enabled;
        devbox = enabled;
        claude-code = enabled;
      };
    };
  };

  home.stateVersion = "24.11";
}
```

- [ ] **Step 3: Verify evaluation**

Run: `nix flake check --no-build --show-trace`
Expected: PASS. If it fails citing a shared home module, capture the error — those are the darwin-incompat fixes in Task 5.

- [ ] **Step 4: Commit**

```bash
git add homes/aarch64-darwin
git commit -m "feat(homes): add usr0200797@TMEN0081 home config"
```

---

## Task 5: Build on the corporate Mac and fix darwin incompatibilities

**Files:** depends on what fails. Most likely candidates: `modules/home/app/dev/{gpg,claude-code,tmux,git}/default.nix`, `modules/home/impermanence/default.nix`.

This task can only be performed on the TMEN0081 hardware. On linux the prior tasks pass `nix flake check`; the actual `darwin-rebuild build` is the real gate.

- [ ] **Step 1: On TMEN0081, fetch the branch and try to build**

```bash
cd ~/Workspaces/nix-config   # or wherever the corporate PC has the checkout
git fetch origin
git checkout <merge-branch>
darwin-rebuild build --flake .#TMEN0081 --show-trace 2>&1 | tee /tmp/darwin-build.log
```

Expected: likely fails on at least one shared home module that uses linux-only paths or packages.

- [ ] **Step 2: For each failure, fix in the shared module (preferred)**

The fix pattern for a linux-only chunk:

```nix
config = mkIf cfg.enable (mkMerge [
  {
    # cross-platform config here
  }
  (mkIf pkgs.stdenv.isLinux {
    # linux-only config here (e.g., capybara.impermanence.directories)
  })
]);
```

For a linux-only package, swap the package conditional on `pkgs.stdenv.hostPlatform.isDarwin`. Avoid forking the module.

- [ ] **Step 3: Re-run the build**

Run: `darwin-rebuild build --flake .#TMEN0081 --show-trace`
Expected: PASS, or a new failure to fix. Repeat steps 2–3 until clean.

- [ ] **Step 4: Switch and verify the system works**

Run: `darwin-rebuild switch --flake .#TMEN0081`
Expected: switch completes, aerospace launches, kitty/git/tmux/etc. work.

- [ ] **Step 5: Commit any darwin-compat fixes**

```bash
git add modules/home
git commit -m "fix(home): make shared modules darwin-compatible"
```

(Skip the commit if no fixes were needed.)

---

## Task 6: Verify cross-host evaluation and merge

**Files:** none modified.

- [ ] **Step 1: From a linux host (helios/m5p01/xanthus), verify nothing regressed**

Run: `nix flake check --show-trace`
Expected: PASS. All four hosts (`helios`, `m5p01`, `xanthus`, `TMEN0081`) listed under `darwinConfigurations` / `nixosConfigurations`.

- [ ] **Step 2: Push the branch and open a PR (or merge to main)**

```bash
git push -u origin <merge-branch>
gh pr create --title "feat: merge confidential-nix-config (TMEN0081)" \
  --body "Adds nix-darwin support and TMEN0081 corporate Mac host. Spec: docs/superpowers/specs/2026-04-28-merge-confidential-nix-config-design.md"
```

- [ ] **Step 3: After merge, archive the confidential repo**

On GitHub: navigate to `mtaku3/confidential-nix-config` → Settings → Archive this repository. Do not delete — this preserves history for reference.

- [ ] **Step 4: Update the corporate PC's checkout to point at public**

On TMEN0081:

```bash
cd ~/Workspaces
mv confidential-nix-config confidential-nix-config.archived
# nix-config should already be checked out from public; if not:
# git clone https://github.com/mtaku3/nix-config.git
cd nix-config
git pull
darwin-rebuild switch --flake .#TMEN0081
```

Expected: corporate PC now rebuilds from public repo.

---

## Acceptance

- `nix flake check` passes on linux for all hosts.
- `darwin-rebuild switch --flake .#TMEN0081` succeeds on the corporate Mac.
- The four pre-existing hosts (`helios`, `m5p01`, `xanthus`) are unchanged in behavior.
- `mtaku3/confidential-nix-config` is archived.
