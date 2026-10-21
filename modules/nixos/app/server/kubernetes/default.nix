{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.kubernetes;
  api = "https://${cfg.masterAddress}:6443";
in {
  disabledModules = [
    "services/cluster/kubernetes/addons/dns.nix"
  ];

  imports = [
    ./mypki.nix
    ./mydns.nix
    ./kube-vip.nix
  ];

  options.capybara.app.server.kubernetes = with types; {
    enable = mkBoolOpt false "Whether to enable the kubernetes";
    advertiseIP = mkOpt types.str "" "IP address to advertise for the Kubernetes API server";
    masterAddress = mkOpt types.str "" "IP address or hostname of the Kubernetes master node";
    role = mkOpt (types.enum ["master" "node"]) "node" "Role of the Kubernetes node";
    etcdEndpoints = mkOpt (types.listOf types.str) [] "List of etcd endpoints";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.etc."kubernetes/resolv.conf" = mkIf config.services.resolved.enable {
        text = concatMapStrings (ns: "nameserver ${ns}\n") config.networking.nameservers;
      };

      services.kubernetes = {
        masterAddress = cfg.masterAddress;
        apiserverAddress = api;
        easyCerts = false;

        apiserver = {
          allowPrivileged = true;
          verbosity = 1; # Warn level
          extraOpts = ''
            --service-node-port-range=0-65534
          '';
        };

        controllerManager.verbosity = 1; # Warn level

        kubelet.verbosity = 1; # Warn level

        # With systemd-resolved, /etc/resolv.conf points at the 127.0.0.53
        # stub, which pods (and CoreDNS's `forward . /etc/resolv.conf`) can't
        # reach from their own network namespace. resolved's upstream file is
        # no good either: it carries link search domains (NetBird's
        # peers.mtaku3.com), which pods with ndots:5 try first, and the public
        # *.mtaku3.com wildcard then answers e.g. api.github.com.peers.mtaku3.com.
        # Hand pods the plain upstream servers only.
        kubelet.extraConfig = mkIf config.services.resolved.enable {
          resolvConf = "/etc/kubernetes/resolv.conf";
        };

        proxy.verbosity = 1; # Warn level

        addons.dns = enabled;

        dataDir = "/var/lib/kubelet";
      };

      virtualisation.containerd.settings.plugins."io.containerd.grpc.v1.cri".containerd.snapshotter = "overlayfs";

      # etcd tuning. extraConf keys are passed verbatim as ETCD_<key> env vars,
      # so they must be UPPERCASE_UNDERSCORE — etcd ignores dashed/lowercase ones.
      services.etcd.extraConf = {
        "LOG_LEVEL" = "warn";
        # Slow storage can't fsync within the 100ms default heartbeat; raise to 300ms.
        "HEARTBEAT_INTERVAL" = "300";
        # election-timeout must be >= 5x heartbeat (10x recommended). 300ms * 10.
        "ELECTION_TIMEOUT" = "3000";

        # Keep the backend db small: drop revisions older than 1h. Smaller db means
        # fewer/smaller pages touched per write, so fewer and cheaper fsyncs.
        "AUTO_COMPACTION_MODE" = "periodic";
        "AUTO_COMPACTION_RETENTION" = "1h";

        # WAL fsync (one per Raft commit) is the unbatchable durability floor. The
        # boltdb backend commit, however, IS batchable: widening the window lets many
        # ops share a single backend fsync. Costs up to 100ms extra backend-commit
        # latency, but the WAL still guarantees durability, so no data risk.
        "BACKEND_BATCH_INTERVAL" = "100ms";
        "BACKEND_BATCH_LIMIT" = "10000";
      };

      # Periodic etcd defrag. Compaction frees revisions logically but leaves the
      # boltdb file fragmented; defrag rewrites it compactly, reclaiming disk and
      # shrinking the page set future writes must fsync. Briefly blocks etcd
      # (~seconds on a small db) — runs off-peak.
      systemd.services.etcd-defrag = {
        description = "Defragment the etcd backend database";
        after = ["etcd.service"];
        requires = ["etcd.service"];
        serviceConfig = {
          Type = "oneshot";
          Environment = ["ETCDCTL_API=3"];
          ExecStart = let
            etcdctl = "${config.services.etcd.package}/bin/etcdctl";
            caFile = config.age.secrets."common/k8s-pki/etcd/ca.crt".path;
            certFile = config.age.secrets."homelab-k8s/etcd/healthcheck-client.crt".path;
            keyFile = config.age.secrets."homelab-k8s/etcd/healthcheck-client.key".path;
          in pkgs.writeShellScript "etcd-defrag" ''
            ${etcdctl} --endpoints=https://127.0.0.1:2379 \
              --cacert=${caFile} --cert=${certFile} --key=${keyFile} \
              defrag --command-timeout=60s
          '';
        };
      };

      systemd.timers.etcd-defrag = {
        description = "Weekly etcd defrag";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "Sun 04:00";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
      };

      # Set flannel log verbosity to warning level (Go log levels: 0=panic, 1=error, 2=warning)
      systemd.services.flannel = mkIf config.services.kubernetes.flannel.enable {
        serviceConfig.Environment = ["GLOG_v=2"];
      };

      capybara.impermanence.directories = [
        {
          directory = "/var/lib/cfssl";
          user = "cfssl";
          group = "cfssl";
          mode = "0700";
        }
        {
          directory = "/var/lib/containerd";
          user = "root";
          group = "root";
          mode = "0755";
        }
        {
          directory = "/var/lib/etcd";
          user = "etcd";
          group = "root";
          mode = "0700";
        }
        {
          directory = "/var/lib/kubelet";
          user = "kubernetes";
          group = "kubernetes";
          mode = "0755";
        }
      ];
    }
    (mkIf (cfg.role == "master") {
      services.kubernetes = {
        roles = ["master" "node"];
        apiserver = {
          securePort = 6443;
          advertiseAddress = cfg.advertiseIP;
        };
        scheduler.address = "0.0.0.0";
        controllerManager.bindAddress = "0.0.0.0";
      };
    })
    (mkIf (cfg.role == "node") {
      services.kubernetes = {
        roles = ["node"];
        kubelet.kubeconfig.server = api;
      };
    })
  ]);
}
