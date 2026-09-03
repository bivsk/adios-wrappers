{ types, ... } @ adios:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Options to be injected into the wrapped package's `config.ghostty`.

        See the ghostty [documentation](https://ghostty.org/docs/config).

        Disjoint with the `configFiles` option.
      '';
      example = {
        cursor-color = "ffffff";
        cursor-text = "000000";
        background = "272822";
        foreground = "ffffff";
      };
      mergeFunc = adios.lib.merge.attrs.recursively;
    };
    configFiles = {
      type = types.listOf types.pathLike;
      description = ''
        A list of `config.ghostty` files to be injected into the wrapped package.

        See the ghostty [documentation](https://ghostty.org/docs/config).

        Disjoint with the `settings` option.
      '';
      mergeFunc = adios.lib.merge.lists.concat;
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.ghostty;
      description = "The ghostty package to be wrapped.";
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (builtins) concatStringSep head length;
      inherit (inputs.nixpkgs.pkgs) formats writeText;
      inherit (inputs.nixpkgs.lib.lists) optionals;

      generator = formats.keyValue {
        listsAsDuplicateKeys = true;
      };

      configPath =
        if length options.configFiles == 1 then
          head options.configFiles
        else
          writeText "config.ghostty" (
            concatStringSep "\n" (map (file: ''config-file "${file}"'') options.configFiles)
          );
    in
    assert !(options ? settings && options ? configFiles);
    inputs.mkWrapper {
      inherit (options) package;
      postWrap = ''
        cp $out/share/systemd/user/app-com.mitchellh.ghostty.service .
        chmod +w app-com.mitchellh.ghostty.service
        cat >> app-com.mitchell.ghostty.service<<EOF
        [Unit]
        Description=Ghostty
        After=graphical-session.target
        After=dbus.socket
        Requires=dbus.socket

        [Service]
        Type=notify-reload
        ReloadSignal=SIGUSR2
        BusName=com.mitchellh.ghostty
        ExecStart=$out/bin/ghostty --gtk-single-instance=true --initial-window=false

        [Install]
        WantedBy=graphical-session.target
        EOF
        cp --remove-destination app-com.mitchellh.ghostty.service $out/share/systemd/user/
      '';
      symlinks = {
        "$out/ghostty/config.ghostty" =
          if options ? configFiles then
            configPath
          else if options ? settings then
            generator.generate "config.ghostty" options.settings
          else
            null;
      };
      flags = optionals (options ? configFiles || options ? settings) [
        "--config-file=$out/ghostty/config.ghostty"
        "--config-default-files=false"
      ];
    };

  meta = {
    maintainers = [ "bivsk" ];
  };
}
