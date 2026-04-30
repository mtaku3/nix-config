{
  pkgs,
  ...
}: let
  opts = {
    defaultGroups = ["default"];

    plugins = {
      default = [
        {
          plugin = "superpowers";
          marketplace = "anthropics/claude-plugins-official";
        }
      ];
    };

    permissions = {
      default = {
        allow = [];
        deny = [];
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
    };
  };
in
  pkgs.callPackage ./package.nix opts
