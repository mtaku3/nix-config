{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.neovim;
in {
  options.capybara.app.dev.neovim = {
    enable = mkBoolOpt false "Whether to enable the neovim";
  };

  config = mkIf cfg.enable (let
    treesitter = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
    treesitterSubstitute = {
      ts_parser_dirs = pkgs.lib.pipe treesitter.dependencies [
        (map toString)
        (concatStringsSep ",")
      ];
    };
    pnamesToSubstitute = let
      pluginsToLazyLoad = with pkgs.vimPlugins; [
        nvim-cmp
        cmp-nvim-lsp
        cmp_luasnip
        luasnip
        copilot-cmp
        copilot-lua
        kanagawa-nvim
        comment-nvim
        fidget-nvim
        indent-blankline-nvim
        indent-o-matic
        knap
        neodev-nvim
        none-ls-nvim
        nvim-notify
        telescope-nvim
        plenary-nvim
        telescope-fzf-native-nvim
        neo-tree-nvim
        nvim-web-devicons
        nui-nvim
        treesitter
        nvim-treesitter-textobjects
        nvim-lspconfig
      ];
      normalizePname = pname: replaceStrings ["-" "."] ["_" "_"] (toLower pname);
    in
      foldl (acc: plugin: acc // {"${normalizePname plugin.pname}" = plugin;}) {} pluginsToLazyLoad;
    configFile = file: opt: {
      "nvim/${file}".source = pkgs.substituteAll ({
          src = ./config + "/${file}";
        }
        // pnamesToSubstitute
        // treesitterSubstitute
        // opt);
    };
    configFiles = let
      files = [
        "./init.lua"
        "./lua/config/init.lua"
        "./lua/config/keymaps.lua"
        "./lua/config/options.lua"
        "./lua/none-ls/init.lua"
        "./lua/plugins/autocompletion.lua"
        "./lua/plugins/colorscheme.lua"
        "./lua/plugins/comment.lua"
        "./lua/plugins/copilot.lua"
        "./lua/plugins/fidget.lua"
        "./lua/plugins/indentation.lua"
        "./lua/plugins/knap.lua"
        "./lua/plugins/neodev.lua"
        "./lua/plugins/none-ls.lua"
        "./lua/plugins/notify.lua"
        "./lua/plugins/telescope.lua"
        "./lua/plugins/tree.lua"
        "./lua/plugins/treesitter.lua"
        "./lua/plugins/whichkey.lua"
        "./lua/plugins/lsp/init.lua"
        "./lua/plugins/lsp/utils.lua"
      ];
    in
      foldl (acc: file: acc // configFile file {}) {} files;
  in {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      plugins = with pkgs.vimPlugins; [lazy-nvim];
      extraPackages = with pkgs; [ripgrep];
      package = pkgs.capybara.neovim-unwrapped;
    };
    xdg.configFile = configFiles;
  });
}
