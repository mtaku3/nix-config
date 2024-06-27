{
  lib,
  pkgs,
  ...
}:
with lib;
with lib.capybara;
  pkgs.vimUtils.buildVimPlugin {
    name = "none-ls-extras-nvim";
    pname = "none-ls-extras-nvim";
    src = pkgs.fetchFromGitHub {
      owner = "nvimtools";
      repo = "none-ls-extras.nvim";
      rev = "336e84b9e43c0effb735b08798ffac382920053b";
      hash = "sha256-UtU4oWSRTKdEoMz3w8Pk95sROuo3LEwxSDAm169wxwk=";
    };
  }
