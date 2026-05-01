{
  pkgs,
  ...
}: let
  opts = {
    defaultGroups = ["default" "memory"];

    plugins = {
      default = [
        {
          plugin = "superpowers";
          marketplace = "anthropics/claude-plugins-official";
        }
      ];
      memory = [
        {
          plugin = "mem0";
          marketplace = "mem0ai/mem0";
        }
      ];
    };

    permissions = {
      default = {
        allow = [];
        deny = [
          "Bash(git add -f *)"
          "Bash(git push -f *)"
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
    };

    mcp = {
      default = {};
      research = {
        paper-search-mcp = {
          type = "stdio";
          command = "uvx";
          args = ["--from" "paper-search-mcp" "python" "-m" "paper_search_mcp.server"];
        };
      };
    };
  };
in
  pkgs.callPackage ./package.nix opts
