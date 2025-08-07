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
    configFiles = let
      treesitter = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
      treesitterSubstitute = {
        ts_parser_dirs = pkgs.lib.pipe treesitter.dependencies [
          (map toString)
          (concatStringsSep ",")
        ];
      };
      plugins = with pkgs.vimPlugins; {
        inherit
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
          which-key-nvim
          lazygit-nvim
          gitsigns-nvim
          ;
        none-ls-extras-nvim = pkgs.capybara.none-ls-extras-nvim;
      };
      normalizePnames = plugins: let
        normalize = pname: replaceStrings ["-" "."] ["_" "_"] (toLower pname);
      in
        foldl (acc: plugin: acc // {"${normalize plugin.pname}" = plugin;}) {} plugins;
      withPlugins = file: plugins: opt: {"nvim/${file}".source = pkgs.replaceVars (./config + "/${file}") (normalizePnames plugins // opt);};
    in
      mkMerge [
        (withPlugins "./init.lua" [] {})
        (withPlugins "./lua/config/init.lua" [] {})
        (withPlugins "./lua/config/keymaps.lua" [] {})
        (withPlugins "./lua/config/options.lua" [] {})
        (withPlugins "./lua/lsp/init.lua" [] {})
        (withPlugins "./lua/none-ls/init.lua" [] {})
        (withPlugins "./lua/plugins/autocompletion.lua" (with plugins; [nvim-cmp cmp-nvim-lsp cmp_luasnip luasnip copilot-cmp copilot-lua]) {})
        (withPlugins "./lua/plugins/colorscheme.lua" (with plugins; [kanagawa-nvim]) {})
        (withPlugins "./lua/plugins/comment.lua" (with plugins; [comment-nvim]) {})
        # (withPlugins "./lua/plugins/copilot.lua" (with plugins; [copilot-lua]) {})
        (withPlugins "./lua/plugins/fidget.lua" (with plugins; [fidget-nvim]) {})
        (withPlugins "./lua/plugins/indentation.lua" (with plugins; [indent-blankline-nvim indent-o-matic]) {})
        # (withPlugins "./lua/plugins/knap.lua" (with plugins; [knap]) {})
        (withPlugins "./lua/plugins/neodev.lua" (with plugins; [neodev-nvim nvim-cmp]) {})
        (withPlugins "./lua/plugins/none-ls.lua" (with plugins; [none-ls-nvim none-ls-extras-nvim]) {})
        (withPlugins "./lua/plugins/notify.lua" (with plugins; [nvim-notify]) {})
        (withPlugins "./lua/plugins/telescope.lua" (with plugins; [telescope-nvim plenary-nvim telescope-fzf-native-nvim]) {})
        (withPlugins "./lua/plugins/tree.lua" (with plugins; [neo-tree-nvim plenary-nvim nvim-web-devicons nui-nvim]) {})
        (withPlugins "./lua/plugins/treesitter.lua" (with plugins; [treesitter nvim-treesitter-textobjects]) treesitterSubstitute)
        # (withPlugins "./lua/plugins/whichkey.lua" (with plugins; [which-key-nvim]) {})
        (withPlugins "./lua/plugins/lsp/init.lua" (with plugins; [nvim-lspconfig nvim-cmp telescope-nvim]) {})
        (withPlugins "./lua/plugins/lazygit.lua" (with plugins; [lazygit-nvim]) {})
        (withPlugins "./lua/plugins/gitsigns.lua" (with plugins; [gitsigns-nvim]) {})
      ];
  in {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      withRuby = false;
      withNodeJs = true;
      plugins = with pkgs; with pkgs.vimPlugins; [lazy-nvim];
      extraPackages = with pkgs; [ripgrep];
      package = pkgs.neovim-unwrapped;
    };
    xdg.configFile = configFiles;

    programs.lazygit = {
      enable = true;
      settings = {
        gui.language = "en";
        os.edit = "nvim --server $NVIM --remote-send '<C-\\><C-n>:q<CR>:lua vim.cmd(\"edit \" .. vim.fn.fnameescape({{filename}}))<CR>'";
      };
    };

    capybara.impermanence.directories = [
      ".config/github-copilot"
    ];
  });
}
