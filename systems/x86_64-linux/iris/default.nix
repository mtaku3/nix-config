{lib, ...}:
with lib;
with lib.capybara; {
  capybara = {
    archetypes.workstation = enabled;
  };

  system.stateVersion = "23.11";
}
