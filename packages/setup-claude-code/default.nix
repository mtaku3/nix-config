{
  pkgs,
  ...
}: let
  opts = {
    defaultGroups = ["default" "memory"];

    postInstall = "";

    plugins = {
      default = [
        {
          plugin = "superpowers";
          marketplace = "anthropics/claude-plugins-official";
        }
        {
          plugin = "andrej-karpathy-skills";
          marketplace = "forrestchang/andrej-karpathy-skills";
        }
        {
          plugin = "caveman";
          marketplace = "JuliusBrussee/caveman";
          postInstall = ''
            mkdir -p "$HOME/.config/caveman"
            cat > "$HOME/.config/caveman/config.json" <<'EOF'
            { "defaultMode": "full" }
            EOF
          '';
        }
        {
          plugin = "claude-hud";
          marketplace = "jarrodwatts/claude-hud";
        }
      ];
      memory = [
        {
          plugin = "mem0";
          marketplace = "mem0ai/mem0";
        }
      ];
      webdev = [
        {
          plugin = "ui-ux-pro-max";
          marketplace = "nextlevelbuilder/ui-ux-pro-max-skill";
        }
      ];
    };

    permissions = {
      default = {
        allow = [];
        deny = [
          "Bash(git add -f *)"
          "Bash(git push -f *)"
          "Bash(git -c *)"
          "Read(.env)"
        ];
        ask = [];
      };
    };

    sandbox = {
      filesystem = {
        allowWrite = [];
        denyWrite = [];
      };
      excludedCommands = [
        "git commit *"
      ];
    };

    mcp = {
      default = {};
      research = {
        paper-search-mcp = {
          type = "stdio";
          command = "uvx";
          args = ["--from" "paper-search-mcp" "python" "-m" "paper_search_mcp.server"];
          postInstall = "";
        };
      };
    };
  };
in
  pkgs.callPackage ./package.nix opts
