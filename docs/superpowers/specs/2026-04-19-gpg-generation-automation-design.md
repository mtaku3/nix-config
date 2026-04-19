# GPG Generation Automation — Design

**Date:** 2026-04-19
**Status:** Draft

## Background

GPG keys for git signing are currently created by hand, following the method in
<https://zenn.dev/mtaku3/articles/07cfa52ab35d2f>:

- NIST P-521 ECC
- Cert-only master key (`[C]`), no expiration
- Three subkeys: `[E]` encrypt, `[S]` sign, `[A]` authenticate
- Exports: `mastersub.key` (master + subs), `sub.key` (subs only), `public.asc`, `revoke.asc`
- On target machines: `gpg --delete-secret-keys $KEYID` then `gpg --import sub.key`

The existing helios host already references a signing key (`4DB490B409F22369`)
produced this way. Secrets in this repo are handled by `agenix` via the existing
`capybara.agenix` module, which auto-loads every `*.age` file under
`secrets/<host>/{system,home/<user>}/` into `config.age.secrets.<relpath>`.

## Goal

Automate the generation step and the NixOS deploy step, while also supporting a
plain "save files to a local directory" mode for non-NixOS systems.

## Non-goals

- **Subkey rotation** under an existing master key — deferred; may be added later
  as a `--rotate-subkeys` flag.
- **Cloud drive upload** (rclone / Google Drive / etc.) — local directory only.
- **Auto-wiring `git.signingKey`** — host configs keep the key id explicit.
- **Encrypting the master key (`mastersub.key`) or revocation cert (`revoke.asc`)
  into agenix** — those stay cold-storage-only and never touch the repo.

## Components

### 1. Generator CLI

**Location:** `packages/gpg-gen/` (Snowfall auto-exposes it as `nix run .#gpg-gen`).

**Shape:** a shell script (`pkgs.writeShellApplication`) that shells out to `gpg`
and, in agenix mode, to `agenix`. It runs on the user's workstation, not inside
a NixOS activation.

**Behaviour:**

1. Parse flags. Exactly one of the following output modes must be supplied:
   - `--agenix --host <hostname> --user <username>` → encrypt into the repo.
   - `--out <dir>` → write raw exported files to `<dir>`.
2. Create a throw-away `GNUPGHOME` under `$(mktemp -d)` so generation is
   isolated from the user's real keyring. The tempdir is removed on exit.
3. Prompt interactively (once) for the key passphrase; reuse it through
   `--pinentry-mode loopback --passphrase-file <fd>`.
4. Generate the master key via `gpg --batch --generate-key` with a param file:
   ```
   Key-Type: ECDSA
   Key-Curve: nistp521
   Key-Usage: cert
   Name-Real: <from --name or prompt>
   Name-Email: <from --email or prompt>
   Expire-Date: 0
   %no-protection   # added before setting passphrase via --change-passphrase
   ```
   (Exact protection flow: generate without passphrase in batch, then set it
   with `gpg --passwd` — avoids pinentry-during-batch edge cases.)
5. Add the three subkeys:
   ```
   gpg --quick-add-key $FPR nistp521 encr never
   gpg --quick-add-key $FPR nistp521 sign never
   gpg --quick-add-key $FPR nistp521 auth never
   ```
6. Export the four files to the tempdir:
   ```
   gpg -a --export-secret-keys       $FPR > mastersub.key
   gpg -a --export-secret-subkeys    $FPR > sub.key
   gpg -a --export                   $FPR > public.asc
   gpg --gen-revoke --batch --yes    $FPR > revoke.asc
   ```
7. Dispatch by mode:
   - **agenix mode:**
     - Verify `secrets/secrets.nix` lists a recipient for `<host>@<user>` (see
       §3). Abort with a helpful message if not.
     - Ensure `secrets/<host>/home/<user>/gpg/` exists.
     - Run `cd secrets && agenix -e <host>/home/<user>/gpg/sub.key.age` piping
       `sub.key` content via `EDITOR=cp` trick, or equivalent — details at
       implementation time; the interface is "the two encrypted files end up
       at the right paths".
     - Copy `public.asc` to `secrets/<host>/home/<user>/gpg/public.asc` as
       plain text (public, no encryption). Committed for reference / GitHub
       upload; the activation script does not consume it (the public half is
       already inside `sub.key`).
     - Print `mastersub.key` and `revoke.asc` absolute paths to stdout with a
       prominent **"MOVE THESE TO COLD STORAGE NOW"** warning. Leave them in
       the tempdir until the user confirms (`Press Enter when moved…`), then
       shred-and-remove.
   - **`--out` mode:**
     - Copy all four files to `<dir>/`. Preserve 0600 perms on the two `.key`
       files. Print the key ID and fingerprint.
8. Print next-step hints: in agenix mode, remind the user to `git add` the new
   files and run `nixos-rebuild`; in `--out` mode, remind that `sub.key` is the
   file to import on machines, `mastersub.key` is cold storage.

**Flag contract (final list):**

| Flag | Required | Meaning |
|---|---|---|
| `--agenix` | mode | Select agenix output mode |
| `--out <dir>` | mode | Select raw-files output mode |
| `--host <h>` | agenix only | Target NixOS host directory |
| `--user <u>` | agenix only | Target home user directory |
| `--name <n>` | no (prompt if missing) | Real name baked into UID |
| `--email <e>` | no (prompt if missing) | Email baked into UID |
| `--help` | no | Usage |

### 2. Home module extension

**Location:** extend `modules/home/app/dev/gpg/default.nix` in-place (no new file —
the module is small and the new behaviour is a natural sibling to the existing
`programs.gpg` / `gpg-agent` config).

**New options under `capybara.app.dev.gpg`:**

```nix
importSubkeys = mkBoolOpt false "Import GPG subkeys from agenix on activation";
keyId         = mkOpt types.str "" "Long GPG key id / fingerprint to expect";
```

**Behaviour when `importSubkeys = true`:**

- Asserts `capybara.agenix.enable` is also true, and `cfg.keyId != ""`.
- References `config.age.secrets."gpg/sub.key".path` (this path name is
  produced by the existing agenix module from `secrets/<host>/home/<user>/gpg/sub.key.age`).
- Adds a home-manager activation script (after `writeBoundary`) that:
  1. Checks whether `gpg --list-secret-keys --with-colons "$KEY_ID"` contains
     the expected fingerprint.
  2. If not, runs `gpg --import "$SUB_KEY_PATH"` — this imports the public
     component too, since secret-key exports include it.
  3. Sets ultimate ownertrust for the master fingerprint via
     `printf '%s:6:\n' "$FPR" | gpg --import-ownertrust`.
- Keeps the existing `.gnupg` impermanence entry so the imported keyring
  actually persists across reboots.

**Why not auto-wire `programs.git.signing.key`?** The git module already takes
`signingKey` as an explicit option set per host. Auto-wiring would couple the
two modules and hide where the key id is defined. Host config stays the single
source of truth (`signingKey = cfg.keyId` is a one-liner if the user wants it).

### 3. `secrets/secrets.nix` recipient registry

Currently absent (the `secrets/` dir is empty). Needs to be created with:

- Each host's SSH host key as a recipient for `<host>/system/*.age` files.
- Each user's SSH user key as a recipient for `<host>/home/<user>/*.age` files.

The generator CLI reads this file before attempting `agenix -e` and aborts
early with a clear diagnostic if the target host/user isn't listed.

Adding recipients is a manual step done once per host, outside this tool.

## Flow diagrams

### Bootstrap for a new NixOS host

1. Operator adds host + user pubkeys to `secrets/secrets.nix`.
2. `nix run .#gpg-gen -- --agenix --host helios --user mtaku3 \
     --name "mtaku3" --email me@mtaku3.com`
3. Enter passphrase when prompted.
4. Tool produces:
   - `secrets/helios/home/mtaku3/gpg/sub.key.age` (encrypted)
   - `secrets/helios/home/mtaku3/gpg/public.asc` (plain)
   - `/tmp/gpg-gen-XXXX/mastersub.key` + `revoke.asc` → operator moves these to
     a USB / encrypted volume; confirms; tool shreds the tempdir.
5. Operator sets `signingKey = "<new KEYID>"` and adds
   `capybara.app.dev.gpg = { importSubkeys = true; keyId = "<FPR>"; }` in
   `homes/x86_64-linux/mtaku3@helios/default.nix`.
6. `git add`, commit, `nixos-rebuild switch`.
7. On next login the activation script imports `sub.key` into `~/.gnupg/`,
   git signing works.

### Non-NixOS generation

1. `nix run .#gpg-gen -- --out /mnt/usb/gpg-backup --name … --email …`
2. Enter passphrase.
3. All four files land in `/mnt/usb/gpg-backup/`.
4. Operator imports `sub.key` on the target machine following the usual Zenn
   steps (`gpg --import sub.key`, `git config …`). Tool does nothing further.

## Error handling

- Missing/conflicting mode flags → usage error, exit 2.
- `secrets/secrets.nix` missing a recipient for the requested target → abort
  before generation; nothing written.
- `agenix` CLI missing from PATH → abort with "run from the devshell or add
  agenix to your system".
- Generation failure mid-way → tempdir is removed via `trap`, no partial state
  in the repo.
- Activation-time import: if `sub.key` decryption fails (agenix not ready
  yet), the activation script logs a warning and exits 0 — doesn't block
  home-manager activation.

## Testing

- Manual: run generator in `--out /tmp/xxx` mode, inspect the four files,
  import into a throwaway `GNUPGHOME`, verify capabilities match the Zenn
  structure (`sec [C]`, three `ssb` lines `[E][S][A]`).
- Manual: full bootstrap on a spare host (or a VM) end-to-end.
- No automated tests — the tool's blast radius is confined to a tempdir and
  the repo's `secrets/` directory, and the interesting surface is the gpg
  invocation sequence which is stable across gpg versions.

## Open implementation details (deferred to plan)

- Exact incantation to feed a file to `agenix -e` non-interactively (agenix
  expects `$EDITOR`; standard trick is `EDITOR="cp <source>"` with care around
  the target path argument it passes).
- Whether to include a `--dry-run` flag.
- Exact copy for the "move to cold storage" prompt.
