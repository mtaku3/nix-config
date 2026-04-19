# gpg-gen

Automates GPG key generation per the Zenn method (NIST P-521, cert-only master,
`[E]/[S]/[A]` subkeys), with two output modes.

## Modes

### `--out DIR` — non-NixOS / manual

Writes `mastersub.key`, `sub.key`, `public.asc`, `revoke.asc` to `DIR`. Nothing
touches the repo. You manage placement/cold-storage yourself.

```
nix run .#gpg-gen -- --out /mnt/usb/gpg-backup --name "Your Name" --email you@example.com
```

### `--agenix --host HOST --user USER` — NixOS via agenix

Encrypts `sub.key` with `age` using the recipients from
`capybara.agenix.hostPubkeys` and `capybara.agenix.userPubkeys` for the target
host/user, places it at `secrets/HOST/home/USER/gpg/sub.key.age` (plus
`public.asc` plain), and prints cold-storage paths for `mastersub.key` and
`revoke.asc`.

```
nix run .#gpg-gen -- --agenix --host helios --user mtaku3 --name mtaku3 --email me@mtaku3.com
```

Afterwards:
1. Move `mastersub.key` and `revoke.asc` off-disk before hitting Enter.
2. `git -C secrets add … && git -C secrets commit …`
3. In the parent repo: set `signingKey` + `capybara.app.dev.gpg.{importSubkeys = true; keyId = "<FPR>";}` on the target host.
4. `git add … && git commit …` (bumps submodule pointer)
5. `nixos-rebuild switch --flake '.?submodules=1#<host>'`

## Running tests

```
nix shell nixpkgs#bats nixpkgs#age nixpkgs#jq -c bats packages/gpg-gen/scripts/tests/
```
