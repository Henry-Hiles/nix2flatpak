{ lib, writeText }:

{ appId
, runtime          # e.g., "org.kde.Platform/6.10"
, sdk ? null
, command
, permissions ? {}
, extraEnv ? {}
, system ? builtins.currentSystem
}:

let
  # Parse runtime: "org.kde.Platform/6.10" → name + branch
  runtimeParts = lib.splitString "/" runtime;
  runtimeName = builtins.elemAt runtimeParts 0;
  runtimeBranch = builtins.elemAt runtimeParts 1;

  # Infer SDK from runtime
  actualSdk = if sdk != null
    then sdk
    else builtins.replaceStrings [ "Platform" ] [ "Sdk" ] runtimeName;

  # Map nix system to flatpak arch
  archMap = {
    "x86_64-linux" = "x86_64";
    "aarch64-linux" = "aarch64";
    "i686-linux" = "i386";
  };
  flatpakArch = archMap.${system} or (throw "Unsupported system: ${system}");
in writeText "flatpak-metadata-${appId}" (
  lib.generators.toINI {} ({
    Application = {
      name = appId;
      command = command;
      runtime = "${runtimeName}/${flatpakArch}/${runtimeBranch}";
      sdk = "${actualSdk}/${flatpakArch}/${runtimeBranch}";
    };

    Context = {
      shared = lib.concatStringsSep ";" permissions.share or [];
      sockets = lib.concatStringsSep ";" permissions.sockets or [];
      devices = lib.concatStringsSep ";" permissions.devices or [];
      filesystems = lib.concatStringsSep ";" permissions.filesystems or [];
    };

    Environment = extraEnv;

    # Apply own-names last to override any duplicate entries.
    # This matches the Flatpak spec, which says "own" implies "talk".
    "Session Bus Policy" = {}
      // builtins.listToAttrs (map (name: ({ name = name; value = "talk"; })) permissions.talk-names or [])
      // builtins.listToAttrs (map (name: ({ name = name; value = "own"; })) permissions.own-names or []);
  })
)
