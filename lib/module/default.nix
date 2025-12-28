{lib, ...}:
with lib; rec {
  mkOpt = type: default: description: mkOption {inherit type default description;};
  mkBoolOpt = mkOpt types.bool;
  enabled = {enable = true;};
  disabled = {enable = false;};
  userConfigs = config: let
    usernames = attrNames config.snowfallorg.users;
  in
    foldl (acc: username: acc // {"${username}" = config.home-manager.users.${username};}) {} usernames;
  users-any = predicate: config: let
    user-configs = attrValues config.home-manager.users;
  in
    lists.any predicate user-configs;
  mkAliasOptionModuleRecursive = from: to: let
    getOptionPathsFromAttrsRecursive = root: options: let
      rootOpt = getAttrFromPath root options;
    in
      foldl (acc: name: let
        opt = getAttrFromPath name rootOpt;
      in
        acc
        ++ (
          if isAttrs opt
          then getOptionPathsFromAttrsRecursive (root ++ name) options
          else if isOption opt
          then [(root ++ name)]
          else []
        )) [] (attrNames rootOpt);
    doRenameRecursive = {
      # List of strings representing the attribute path of the old option.
      from,
      # List of strings representing the attribute path of the new option.
      to,
      # Boolean, whether the old option is to be included in documentation.
      visible,
      # Whether to warn when a value is defined for the old option.
      # NOTE: This requires the NixOS assertions module to be imported, so
      #        - this generally does not work in submodules
      #        - this may or may not work outside NixOS
      warn,
      # A function that is applied to the option value, to form the value
      # of the old `from` option.
      #
      # For example, the identity function can be passed, to return the option value unchanged.
      # ```nix
      # use = x: x;
      # ```
      #
      # To add a warning, you can pass the partially applied `warn` function.
      # ```nix
      # use = lib.warn "Obsolete option `${opt.old}' is used. Use `${opt.to}' instead.";
      # ```
      use,
      # Legacy option, enabled by default: whether to preserve the priority of definitions in `old`.
      withPriority ? true,
      # A boolean that defines the `mkIf` condition for `to`.
      # If the condition evaluates to `true`, and the `to` path points into an
      # `attrsOf (submodule ...)`, then `doRename` would cause an empty module to
      # be created, even if the `from` option is undefined.
      # By setting this to an expression that may return `false`, you can inhibit
      # this undesired behavior.
      #
      # Example:
      #
      # ```nix
      # { config, lib, ... }:
      # let
      #   inherit (lib) mkOption mkEnableOption types doRename;
      # in
      # {
      #   options = {
      #
      #     # Old service
      #     services.foo.enable = mkEnableOption "foo";
      #
      #     # New multi-instance service
      #     services.foos = mkOption {
      #       type = types.attrsOf (types.submodule …);
      #     };
      #   };
      #   imports = [
      #     (doRename {
      #       from = [ "services" "foo" "bar" ];
      #       to = [ "services" "foos" "" "bar" ];
      #       visible = true;
      #       warn = false;
      #       use = x: x;
      #       withPriority = true;
      #       # Only define services.foos."" if needed. (It's not just about `bar`)
      #       condition = config.services.foo.enable;
      #     })
      #   ];
      # }
      # ```
      condition ? true,
    }: {
      config,
      options,
      ...
    }: let
      fromPaths = getOptionPathsFromAttrsRecursive from options;
      paths = let
        dropLength = length from;
      in
        map (x: {
          fst = x;
          snd = to ++ (drop dropLength x);
        })
        fromPaths;
      toOf = attrByPath to (abort "Renaming error: option `${showOption to}' does not exist.");
      toType = let
        opt = attrByPath to {} options;
      in
        opt.type or (types.submodule {});
    in {
      options = mkMerge (map (x: let
        from = x.fst;
        to = x.snd;
      in
        setAttrByPath from (
          mkOption {
            inherit visible;
            description = "Alias of {option}`${showOption to}`.";
            apply = x: use (toOf config);
          }
          // optionalAttrs (toType != null) {
            type = toType;
          }
        ))
      paths);
      config = mkIf condition (mkMerge foldl (acc: path: let
        from = path.fst;
        to = path.snd;
        fromOpt = getAttrFromPath from options;
      in
        acc
        ++ [
          (optionalAttrs (options ? warnings) {
            warnings =
              optional (warn && fromOpt.isDefined)
              "The option `${showOption from}' defined in ${showFiles fromOpt.files} has been renamed to `${showOption to}'.";
          })
          (
            if withPriority
            then mkAliasAndWrapDefsWithPriority (setAttrByPath to) fromOpt
            else mkAliasAndWrapDefinitions (setAttrByPath to) fromOpt
          )
        ]) []
      paths);
    };
  in
    doRenameRecursive {
      inherit from to;
      visible = true;
      warn = false;
      use = id;
    };
}
