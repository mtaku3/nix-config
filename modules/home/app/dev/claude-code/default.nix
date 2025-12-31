{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.claude-code;
in {
  options.capybara.app.dev.claude-code = {
    enable = mkBoolOpt false "Whether to enable the claude-code";
  };

  config = mkIf cfg.enable {
    programs.claude-code = {
      enable = true;
      memory.source = ./CLAUDE.md;
      settings = {
        theme = "dark";
        autoUpdates = false;
        includeCoAuthoredBy = false;
        autoCompactEnabled = true;
        enableAllProjectMcpServers = true;
        feedbackSurveyState.lastShownTime = 1754089004345;
        outputStyle = "Explanatory";

        permissions = {
          deny = [
            "Bash(rm -rf /*)"
            "Bash(rm -rf /)"
            "Bash(sudo rm -:*)"
            "Bash(chmod 777 /*)"
            "Bash(chmod -R 777 /*)"
            "Bash(dd if=:*)"
            "Bash(mkfs.:*)"
            "Bash(fdisk -:*)"
            "Bash(format -:*)"
            "Bash(shutdown -:*)"
            "Bash(reboot -:*)"
            "Bash(halt -:*)"
            "Bash(poweroff -:*)"
            "Bash(killall -:*)"
            "Bash(pkill -:*)"
            "Bash(nc -l -:*)"
            "Bash(ncat -l -:*)"
            "Bash(netcat -l -:*)"
            "Bash(rm -rf ~:*)"
            "Bash(rm -rf $HOME:*)"
            "Bash(rm -rf ~/.ssh*)"
            "Bash(rm -rf ~/.config*)"
          ];
        };

        env = {
          BASH_DEFAULT_TIMEOUT_MS = "300000";
          BASH_MAX_TIMEOUT_MS = "1200000";
          CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR = "1";
          MAX_MCP_OUTPUT_TOKENS = "50000";
          MCP_TOOL_TIMEOUT = "120000";
          CLAUDE_CODE_MAX_OUTPUT_TOKENS = "32000";
          CLAUDE_CODE_AUTO_CONNECT_IDE = "0";
          CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
          CLAUDE_CODE_ENABLE_TELEMETRY = "0";
          CLAUDE_CODE_IDE_SKIP_AUTO_INSTALL = "1";
          CLAUDE_CODE_IDE_SKIP_VALID_CHECK = "1";
          DISABLE_AUTOUPDATER = "1";
          DISABLE_ERROR_REPORTING = "1";
          DISABLE_INTERLEAVED_THINKING = "1";
          DISABLE_MICROCOMPACT = "1";
          DISABLE_NON_ESSENTIAL_MODEL_CALLS = "1";
          DISABLE_TELEMETRY = "1";
          ENABLE_EXPERIMENTAL_MCP_CLI = "false";
          ENABLE_TOOL_SEARCH = "true";
        };

        statusLine = {
          type = "command";
          command = ./scripts/statusline.sh;
          padding = 0;
        };
      };

      agents = foldl (acc: path: let
        filename = snowfall.path.get-file-name-without-extension path;
      in
        acc // {"${filename}" = builtins.readFile path;}) {} (snowfall.fs.get-files ./agents);

      commands = foldl (acc: path: let
        filename = snowfall.path.get-file-name-without-extension path;
      in
        acc // {"${filename}" = builtins.readFile path;}) {} (snowfall.fs.get-files ./commands);

      hooks = foldl (acc: path: let
        filename = snowfall.path.get-file-name-without-extension path;
      in
        acc // {"${filename}" = builtins.readFile path;}) {} (snowfall.fs.get-files ./hooks);

      skills = let
        base-path = ./skills;
        prefix-to-remove = "${base-path}/";
      in
        foldl (acc: path: let
          skill = removePrefix prefix-to-remove (removeSuffix "/SKILL.md" (builtins.unsafeDiscardStringContext path));
        in
          acc // {"${skill}" = builtins.readFile path;}) {} (snowfall.fs.get-files-recursive base-path);

      mcpServers = let
        mcp-module = inputs.mcp-servers-nix.lib.evalModule pkgs {
          programs = {
            context7.enable = true;
            codex.enable = true;
            serena = {
              enable = true;
              context = "claude-code";
              enableWebDashboard = false;
            };
          };
        };
      in
        mcp-module.config.settings.servers;
    };

    capybara.impermanence.directories = [".claude"];
    capybara.impermanence.files = [".claude.json"];
  };
}
