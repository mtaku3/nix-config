{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.desktop.xserver.windowManager.xmonad;
  xmonad = pkgs.xmonad-with-packages.override {
    ghcWithPackages = pkgs.haskellPackages.ghcWithPackages;
    packages = self: [
      self.xmonad-contrib
      self.xmonad-extras
      self.extra
    ];
  };
in {
  options.capybara.desktop.xserver.windowManager.xmonad = {
    enable = mkBoolOpt false "Whether to enable the XMonad";
  };

  config = let
    xmonadHs = pkgs.substituteAll {
      src = ./xmonad.hs;
      wallpaper = "${pkgs.capybara.wallpapers}/wallhaven-3zmr6y.jpg";
    };
    libFiles = {};
    xmonadBin = "${
      pkgs.runCommandLocal "xmonad-compile" {
        nativeBuildInputs = [xmonad];
      } ''
        mkdir -p $out/bin

        export XMONAD_CONFIG_DIR="$(pwd)/xmonad-config"
        export XMONAD_DATA_DIR="$(pwd)/data"
        export XMONAD_CACHE_DIR="$(pwd)/cache"

        mkdir -p "$XMONAD_CONFIG_DIR/lib" "$XMONAD_CACHE_DIR" "$XMONAD_DATA_DIR"

        cp ${xmonadHs} xmonad-config/xmonad.hs

        declare -A libFiles
        libFiles=(${
          concatStringsSep " "
          (mapAttrsToList (name: value: "['${name}']='${value}'")
            libFiles)
        })
        for key in "''${!libFiles[@]}"; do
          cp "''${libFiles[$key]}" "xmonad-config/lib/$key";
        done

        xmonad --recompile

        # The resulting binary name depends on the arch and os
        # https://github.com/xmonad/xmonad/blob/56b0f850bc35200ec23f05c079eca8b0a1f90305/src/XMonad/Core.hs#L565-L572
        if [ -f "$XMONAD_DATA_DIR/xmonad-${pkgs.stdenv.hostPlatform.system}" ]; then
          # xmonad 0.15.0
          mv "$XMONAD_DATA_DIR/xmonad-${pkgs.stdenv.hostPlatform.system}" $out/bin/
        else
          # xmonad 0.17.0 (https://github.com/xmonad/xmonad/commit/9813e218b034009b0b6d09a70650178980e05d54)
          mv "$XMONAD_CACHE_DIR/xmonad-${pkgs.stdenv.hostPlatform.system}" $out/bin/
        fi
      ''
    }/bin/xmonad-${pkgs.stdenv.hostPlatform.system}";
  in
    mkIf cfg.enable (mkMerge [
      {
        capybara.desktop.xserver.enable = mkForce true;
        capybara.app.desktop.networkmanagerapplet.enable = mkForce true;
        home.packages = [(lowPrio xmonad)];
        home.file = mapAttrs' (name: value:
          attrsets.nameValuePair (".xmonad/lib/" + name) {source = value;})
        libFiles;
      }
      {
        home.file.".xmonad/xmonad.hs".source = xmonadHs;
        home.file.".xmonad/xmonad-${pkgs.stdenv.hostPlatform.system}" = {
          source = xmonadBin;
          onChange = ''
            # Attempt to restart xmonad if X is running.
            if [[ -v DISPLAY ]]; then
              ${xmonadBin} --restart
            fi
          '';
        };
      }
    ]);
}
