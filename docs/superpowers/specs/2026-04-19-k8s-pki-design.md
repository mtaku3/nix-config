# k8s-pki: In-Repo Kubernetes PKI Generator — Design

**Status:** Approved (2026-04-19)
**Author:** mtaku3
**Supersedes:** external [`github:mtaku3/kubecerts`](https://github.com/mtaku3/kubecerts) flake input

## Goal

Replace the external `kubecerts` Go tool with an in-repo, Nix-native automation
that generates, renews, and rotates the Kubernetes cluster PKI for the
`homelab` cluster. All cert material is encrypted with `agenix` and committed
to the `secrets/` submodule. The tool's only runtime is `pkgs.cfssl`,
`pkgs.age`, `pkgs.openssl`, `pkgs.jq`, `pkgs.git` — no external binaries.

## Non-goals

- Deploy orchestration. Committing secrets and running `nixos-rebuild switch`
  stay manual; the tool prints `.age` changes and stops.
- Runtime `nix eval` from shell. All host/user/spec data is resolved at Nix
  evaluation time and baked into the package derivation.
- Cert-lifecycle heroics (auto-renewal daemons, ACME, etc.).

## PKI lifecycle model

- **CAs are long-lived.** Cluster CA, etcd CA, front-proxy CA: 10-year expiry.
  Not touched on `renew`. Rotated only via explicit `rotate-ca`.
- **Leaves are short-lived.** 1-year expiry. Renewed in place when within 30d
  of expiry.
- **Service-account signing keypair** (`sa.pub`/`sa.key`) is a plain RSA 2048
  keypair — no x509. Rotated together with the cluster CA.

## Commands

All under one Snowfall-nested package, invoked via `nix run`:

```
nix run .#k8s-pki.bootstrap [--force] [--dry-run]
nix run .#k8s-pki.renew     [--host H] [--user U] [--cert NAME] [--force] [--dry-run]
nix run .#k8s-pki.rotate-ca [--ca NAME] [--dry-run]
nix run .#k8s-pki.status    [-v] [--json]
```

### `bootstrap` — convergent generator

Idempotent; safe to run repeatedly. Per cert spec entry, does the minimum
needed:

| Detected state | Action |
|---|---|
| Missing file | Generate + encrypt |
| Exists, recipients ≠ current policy | Decrypt with operator identity, re-encrypt |
| Exists, within 30d of expiry | Re-sign leaf (as in `renew`); CAs never touched here |
| Current | Skip |

`--force` re-signs all leaves regardless of expiry (CAs still untouched).
`--dry-run` prints the plan without touching any file.

Adding a new host or user is: edit `systems/` or `homes/`, run `bootstrap`,
commit, rebuild.

### `renew` — leaf-only re-sign

Same convergence logic restricted to "re-sign" actions. CA files are never
read-modify-written; their plaintext is only read to sign leaves. Scope flags
`--host`, `--user`, `--cert` combinable. `--force` ignores the 30-day
threshold.

### `rotate-ca` — explicit CA rotation

Regenerates CAs (default: all three + SA keypair) and every leaf signed by
them. Interactive confirmation (`type ROTATE to continue`) when stdin is a
tty. Warns that:

- All kubeconfigs need re-issued CA trust (home module regenerates
  `~/.kube/config` on next `nixos-rebuild` because `ca.crt` comes from
  agenix).
- Cluster-wide restart required: kube-apiserver, controller-manager,
  scheduler, kubelet, kube-proxy, flannel, etcd.

`--ca NAME` scopes to one CA (`ca`, `etcd/ca`, or `front-proxy-ca`); only
leaves signed by that CA are re-signed.

### `status` — read-only report

Decrypts every file the operator can access and prints:

- Expiry per cert (color-coded: green >30d, yellow <30d, red <7d/expired).
- Recipient drift per file (`.age` recipients ≠ current policy).
- Missing files referenced by `specs.nix`.
- Stray files on disk not in `specs.nix`.

`--json` emits machine-readable output. Exits `3` if drift/missing/stale is
detected (useful for CI).

### Exit codes

- `0` — success / no action needed
- `1` — operational error (missing dep, decrypt/cfssl failure)
- `2` — user error (bad flag, unknown name, host not in cluster)
- `3` — `status` detected drift

### Shared invariants

- All cert material lives in `mktemp -d` with `trap` cleanup; no plaintext
  persists after exit.
- Non-tty runs proceed without confirmation; tty runs prompt before
  destructive actions (`rotate-ca`, overwrite with `--force`).
- One log line per file action: `generated`, `re-encrypted`, `skipped
  current`, `will renew`. `--dry-run` output is the plan.

## Storage layout

```
secrets/
├── common/
│   └── k8s-pki/                        # shared CAs + SA keypair
│       ├── ca.{crt,key}.age
│       ├── etcd/ca.{crt,key}.age
│       ├── front-proxy-ca.{crt,key}.age
│       └── sa.{pub,key}.age
├── <host>/
│   ├── system/
│   │   └── homelab-k8s/                # per-host system leaves
│   │       ├── apiserver.{crt,key}.age                 (master only)
│   │       ├── apiserver-etcd-client.{crt,key}.age
│   │       ├── apiserver-kubelet-client.{crt,key}.age
│   │       ├── front-proxy-client.{crt,key}.age
│   │       ├── controller-manager{,-client}.{crt,key}.age
│   │       ├── scheduler{,-client}.{crt,key}.age
│   │       ├── addon-manager-client.{crt,key}.age
│   │       ├── cluster-admin-client.{crt,key}.age      (kube-addon-manager's kubeconfig)
│   │       ├── kubelet{,-client}.{crt,key}.age
│   │       ├── kube-proxy-client.{crt,key}.age
│   │       ├── flannel-client.{crt,key}.age
│   │       ├── flannel-etcd-client.{crt,key}.age
│   │       └── etcd/{server,peer,healthcheck-client}.{crt,key}.age
│   └── home/
│       └── <user>/
│           └── homelab-k8s/            # per-user kubeconfig certs
│               ├── ca.crt.age
│               └── cluster-admin.{crt,key}.age
```

### Why split `common/` out?

- CAs and SA keypair are cluster-wide, not host-scoped. The current flat
  layout under `secrets/m5p01/system/homelab-k8s/` works only because there
  is exactly one host. Adding a second master would require copying every CA
  file under another host dir — sketchy.
- The layout matches the PKI mental model: "shared trust anchors" vs.
  "per-host operational certs" vs. "per-user client certs."

### Walker changes

- `modules/nixos/agenix/default.nix`: aggregate from two roots —
  `secrets/common/**` and `secrets/${host}/system/**`. Resulting
  `age.secrets` keys:
  - `common/k8s-pki/ca.crt` for files under `secrets/common/`
  - `homelab-k8s/apiserver.crt` for files under `secrets/${host}/system/homelab-k8s/`
- `modules/home/agenix/default.nix`: unchanged; already walks
  `secrets/${host}/home/${username}/**`.

## Identity & recipient model

### Module option additions

| Module | Option | Source of truth |
|---|---|---|
| `modules/nixos/agenix/default.nix` | `capybara.agenix.hostPubkeys : listOf str` | Set per host in `systems/x86_64-linux/<host>/default.nix` |
| `modules/home/agenix/default.nix`  | `capybara.agenix.userPubkeys : listOf str` | Set per user in `homes/x86_64-linux/<user>@<host>/default.nix` |

These expose *age recipient public keys* (separate from SSH auth
`capybara.openssh.keys`, even if the same material).

### Recipient policy (`lib/k8s-pki/recipients.nix`)

A pure function `{ hosts, users } → recipientsByFile`. Rules, in order of
specificity:

| File category | Recipients |
|---|---|
| `common/k8s-pki/*.crt`, `sa.pub` (public halves of CAs) | Every k8s-enabled host's `hostPubkeys` + every kubectl user's `userPubkeys` |
| `common/k8s-pki/*.key`, `sa.key` (private halves of CAs) | **Master** hosts' `hostPubkeys` + every kubectl user's `userPubkeys` |
| `<host>/system/homelab-k8s/**` | That host's `hostPubkeys` + every kubectl user's `userPubkeys` |
| `<host>/home/<user>/homelab-k8s/**` | That user's `userPubkeys` |

Users in "every kubectl user" = home-manager users with
`capybara.app.dev.kube-cli.enable == true`. Hosts in "every k8s-enabled host"
= NixOS configurations with `capybara.app.server.kubernetes.enable == true`.

**Rationale for the public/private split on `common/`:** limits blast radius
if a worker node is compromised (it can decrypt trust anchors but not CA
signing keys).

### Operator model

The operator runs commands on their laptop using their own age identity
(normally `~/.config/age/keys.txt` or SSH key loaded into `ssh-agent`). Host
private keys never leave the host they were generated on.

- **Encryption** uses *public keys only*, read from the resolved policy map.
- **Decryption** uses whichever identity `age -d` picks up; recipient policy
  ensures the operator's user pubkey is always in the recipient set for any
  file the operator needs to read.

## Tool internals

### Directory layout

```
lib/k8s-pki/
├── default.nix         # { specs = import ./specs.nix; recipients = import ./recipients.nix; }
├── specs.nix           # Static PKI data: CAs, leaves, users, profiles
└── recipients.nix      # { hosts, users } → recipientsByFile policy

packages/k8s-pki/
├── default.nix         # Emits { bootstrap; renew; rotate-ca; status; }
├── data.nix            # inputs.self + lib.capybara.k8s-pki → data.json (baked into drv)
└── scripts/
    ├── lib.sh
    ├── cmd-bootstrap.sh
    ├── cmd-renew.sh
    ├── cmd-rotate-ca.sh
    └── cmd-status.sh
```

Snowfall auto-exports:
- `lib/k8s-pki/default.nix` → `lib.capybara.k8s-pki.{specs,recipients}`
  (consumed by `mypki.nix` without any file-path import).
- `packages/k8s-pki/default.nix` → `packages.${system}.k8s-pki.{bootstrap,renew,rotate-ca,status}`.

### `specs.nix` — static PKI data

```nix
{
  cas = {
    "ca"             = { CN = "kubernetes-ca";             expiry = "87600h"; };
    "etcd/ca"        = { CN = "etcd-ca";                   expiry = "87600h"; };
    "front-proxy-ca" = { CN = "kubernetes-front-proxy-ca"; expiry = "87600h"; };
  };

  sa = { algo = "rsa"; keyBits = 2048; };

  leaves = {
    "apiserver" = {
      signer = "ca";
      CN = "kube-apiserver";
      hostsFromHost = h: [
        "kubernetes" "kubernetes.default"
        "kubernetes.default.svc" "kubernetes.default.svc.cluster.local"
        "127.0.0.1" h.advertiseIP
      ];
      profile = "server";
      expiry  = "8760h";
      scope   = "master";
    };
    "kubelet" = {
      signer = "ca";
      CN     = h: "system:node:${h.name}";
      O      = "system:nodes";
      hostsFromHost = h: [ h.name h.advertiseIP ];
      profile = "server";
      expiry  = "8760h";
      scope   = "all";
    };
    "etcd/server" = { signer = "etcd/ca"; CN = "etcd-server"; profile = "server-etcd"; scope = "master"; /* … */ };
    "etcd/peer"   = { signer = "etcd/ca"; CN = "etcd-peer";   profile = "peer-etcd";   scope = "master"; /* … */ };
    # … all other leaves referenced by mypki.nix
  };

  users = {
    "cluster-admin" = {
      signer = "ca"; CN = "kubernetes-admin"; O = "system:masters";
      profile = "client"; expiry = "8760h";
    };
  };

  profiles = {
    server      = { usages = [ "signing" "key encipherment" "server auth" ]; };
    client      = { usages = [ "signing" "key encipherment" "client auth" ]; };
    server-etcd = { usages = [ "signing" "key encipherment" "server auth" "client auth" ]; };
    peer-etcd   = { usages = [ "signing" "key encipherment" "server auth" "client auth" ]; };
  };
}
```

Every leaf declares `scope` (`master` | `all` | `user`) so `bootstrap`
and `renew` iterate hosts correctly.

### `data.nix` — build-time flake introspection

```nix
{ self, lib }:
let
  k8sLib = lib.capybara.k8s-pki;
  cfgs   = self.nixosConfigurations;

  k8sHosts = lib.filterAttrs
    (_: v: v.config.capybara.app.server.kubernetes.enable) cfgs;

  hosts = lib.mapAttrs (name: v: {
    inherit name;
    inherit (v.config.capybara.app.server.kubernetes) role advertiseIP masterAddress;
    hostPubkeys = v.config.capybara.agenix.hostPubkeys;
  }) k8sHosts;

  users = lib.concatMapAttrs (hostName: v:
    lib.mapAttrs' (uname: u:
      lib.nameValuePair "${uname}@${hostName}" {
        name = uname;
        host = hostName;
        userPubkeys = u.capybara.agenix.userPubkeys;
      })
      (lib.filterAttrs (_: u: u.capybara.app.dev.kube-cli.enable)
        v.config.home-manager.users)
  ) k8sHosts;

  specs      = k8sLib.specs;
  recipients = k8sLib.recipients { inherit hosts users; };
in
  { inherit hosts users specs recipients; }
```

### `packages/k8s-pki/default.nix` — subcommand drvs

```nix
{ lib, pkgs, inputs, ... }:
let
  data     = import ./data.nix { inherit (inputs) self; inherit lib; };
  dataJson = pkgs.writeText "k8s-pki-data.json" (builtins.toJSON data);

  mkCmd = name: script: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [ cfssl age openssl jq git coreutils ];
    text = ''
      export K8S_PKI_DATA=${dataJson}
      export K8S_PKI_LIB=${./scripts/lib.sh}
      ${builtins.readFile script}
    '';
  };
in {
  bootstrap  = mkCmd "k8s-pki-bootstrap"  ./scripts/cmd-bootstrap.sh;
  renew      = mkCmd "k8s-pki-renew"      ./scripts/cmd-renew.sh;
  rotate-ca  = mkCmd "k8s-pki-rotate-ca"  ./scripts/cmd-rotate-ca.sh;
  status     = mkCmd "k8s-pki-status"     ./scripts/cmd-status.sh;
}
```

Zero `nix eval` calls at shell runtime. Changing a host config invalidates
the `dataJson` derivation, Nix rebuilds it on the next `nix run`, shell sees
new JSON.

### Shell script responsibilities

- `scripts/lib.sh` — wrappers: `age_encrypt_to RECIPIENTS FILE PLAINTEXT`,
  `age_decrypt FILE`, `cfssl_gen_ca SPEC OUTDIR`,
  `cfssl_gen_leaf SPEC CA_DIR OUTDIR`, `pem_expiry_days PEM_FILE`,
  `age_recipients_of CIPHERTEXT`.
- `cmd-*.sh` — thin command runners that read plan from `$K8S_PKI_DATA`,
  iterate hosts/leaves, call helpers. All filesystem paths are computed from
  the data JSON (no hardcoded secret paths).

## `mypki.nix` integration

Switch path prefixes and add assertions.

```nix
let
  pki = lib.capybara.k8s-pki.specs;
  ca   = name: config.age.secrets."common/k8s-pki/${name}".path;   # CAs + SA
  host = name: config.age.secrets."homelab-k8s/${name}".path;      # per-host leaves
in {
  services.kubernetes = {
    caFile = ca "ca.crt";
    apiserver = {
      tlsCertFile                  = host "apiserver.crt";
      tlsKeyFile                   = host "apiserver.key";
      serviceAccountKeyFile        = ca "sa.pub";
      serviceAccountSigningKeyFile = ca "sa.key";
      # …
    };
    controllerManager.extraOpts = concatStringsSep " " [
      "--cluster-signing-key-file=${ca "ca.key"}"
      # …
    ];
    # …
  };

  systemd.services.kube-apiserver.restartTriggers = [
    config.age.secrets."homelab-k8s/apiserver.crt".file
    config.age.secrets."common/k8s-pki/ca.crt".file
  ];
  # similar restartTriggers for controller-manager, scheduler, kubelet,
  # kube-proxy, flannel, etcd

  assertions = [
    { assertion = all (n: config.age.secrets ? "common/k8s-pki/${n}.crt")
                      (attrNames pki.cas);
      message = "k8s-pki CA declared in specs.nix but no corresponding agenix secret"; }
    { assertion = all (n: config.age.secrets ? "homelab-k8s/${n}.crt")
                      (attrNames (filterAttrs (_: l: l.scope != "user") pki.leaves));
      message = "k8s-pki leaf declared in specs.nix but no corresponding agenix secret"; }
  ];
}
```

`restartTriggers` ensure `nixos-rebuild switch` restarts services whose
backing ciphertexts changed — this is what makes `renew` actually take
effect on the host.

## Migration (one-time)

1. **Add module changes, no behavior change yet**
   - `capybara.agenix.hostPubkeys` on system agenix module + set it on each
     `systems/x86_64-linux/<host>/default.nix`.
   - `capybara.agenix.userPubkeys` on home agenix module + set it on each
     home config.
   - System agenix walker extended to `secrets/common/**` (still empty).
   - `lib/k8s-pki/*` and `packages/k8s-pki/*` land but aren't yet invoked.

2. **Run `nix run .#k8s-pki.rotate-ca`** locally. Generates fresh PKI in the
   new layout. Acceptable wholesale replacement of current certs since there
   is one host today.

3. **Switch `mypki.nix` to new path helpers** and add spec-driven
   assertions. Remove any references to `homelab-k8s/ca.*`,
   `homelab-k8s/sa.*`, `homelab-k8s/front-proxy-ca.*`,
   `homelab-k8s/etcd/ca.*` (those now live under `common/`).

4. **Delete deprecated pieces**
   - `flake.nix`: remove `kubecerts` input
   - `packages/kubecerts/`: delete
   - `modules/nixos/app/server/kubernetes/pki.nix`: delete (unused upstream cfssl variant)
   - `modules/home/app/dev/kube-cli/default.nix`: remove
     `pkgs.capybara.kubecerts` from `home.packages`. Optionally add
     `pkgs.capybara.k8s-pki.status` for on-host expiry checks.

5. **`nixos-rebuild switch`** on m5p01. Verify cluster comes up.

6. **Commit** secrets submodule + parent in one atomic-feeling change
   (`feat: replace kubecerts with in-repo k8s-pki`).

### Rollback

`git revert` the submodule commit + parent commit restores the prior PKI
(old ciphertexts still in submodule history). After any further
`rotate-ca`, rollback requires regenerating again.

## Open items (deferred)

- **Cluster admin beyond `mtaku3`.** When a second kubectl user is added,
  `data.nix` picks them up automatically — no code change.
- **Multi-master.** The spec's `scope = "master"` iteration already handles
  N masters. etcd topology still hardcoded in `mypki.nix` (`initialCluster`,
  `listenPeerUrls`) — needs its own follow-up when that day comes.
- **Token rotation for `kube-addon-manager`.** Not in scope; current
  kubeconfig-based auth is fine.
- **`status` exporter.** Prometheus endpoint for expiry surveillance could
  come later; for now, run `status -v` manually or cron it on the laptop.
