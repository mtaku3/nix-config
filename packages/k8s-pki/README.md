# k8s-pki

In-repo Kubernetes PKI manager for the homelab cluster. Generates, renews,
and rotates CAs and leaves encrypted with agenix.

## Commands

```
nix run '.?submodules=1#k8s-pki.status'                          # report (exits 3 on drift)
nix run '.?submodules=1#k8s-pki.bootstrap'                       # converge (idempotent)
nix run '.?submodules=1#k8s-pki.renew'                           # re-sign near-expiry leaves
nix run '.?submodules=1#k8s-pki.renew'     -- --force            # re-sign every leaf
nix run '.?submodules=1#k8s-pki.renew'     -- --host HOST        # scope to one host
nix run '.?submodules=1#k8s-pki.renew'     -- --user USER@HOST   # scope to one user
nix run '.?submodules=1#k8s-pki.renew'     -- --cert NAME        # scope to one cert kind
nix run '.?submodules=1#k8s-pki.rotate-ca'                       # regen CAs + all leaves
nix run '.?submodules=1#k8s-pki.rotate-ca' -- --ca NAME          # one CA only
```

All commands accept `--dry-run`.

## Identity

The operator must export `AGENIX_IDENTITIES` (newline-separated paths to age
identity files) before running any command that decrypts ciphertexts
(`renew`, `rotate-ca`, `status`, `bootstrap` when existing files are
present):

```
export AGENIX_IDENTITIES=$HOME/Downloads/agenix/mtaku3@m5p01
```

## Deploy loop

```
nix run '.?submodules=1#k8s-pki.renew'
cd secrets && git add -A && git commit -m "…"
cd .. && git add secrets && git commit -m "…"
nixos-rebuild switch --flake '.?submodules=1#<host>' \
    --target-host mtaku3@<host-ip> --sudo --ask-sudo-password
```

`restartTriggers` in `mypki.nix` cause `nixos-rebuild switch` to restart
kube-apiserver/controller-manager/scheduler/kubelet/kube-proxy/flannel/etcd
whenever their backing `.age` files change, so renewed certs take effect on
the next switch.

## Design

See `docs/superpowers/specs/2026-04-19-k8s-pki-design.md`.
