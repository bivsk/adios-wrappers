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
        Settings to be injected into the wrapped package's `foot.ini`.

        Further information can be found in foot's man page:
        {manpage}`foot.ini(5)`.

        Disjoint with the `configFile` option.
      '';
      mergeFunc = adios.lib.merge.attrs.recursively;
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `foot.ini` file to be injected into the wrapped package.

        Further information can be found in foot's man page:
        {manpage}`foot.ini(5)`.

        Disjoint with the `settings` option.
      '';
    };
    package = {
      type = types.derivation;
      description = "The foot package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.foot;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.lib) optionals;
      inherit (inputs.nixpkgs.lib.generators) mkKeyValueDefault mkValueStringDefault;
      generator = inputs.nixpkgs.pkgs.formats.ini {
        listsAsDuplicateKeys = true;
        mkKeyValue = mkKeyValueDefault {
          mkValueString =
            v:
            mkValueStringDefault {} (
              if v == true then
                "yes"
              else if v == false then
                "no"
              else if v == null then
                "none"
              else
                v
            );

        } "=";
      };
      configFlag = optionals (options ? settings || options ? configFile) [
        "--config"
        "$out/foot/foot.ini"
      ];
    in
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper {
      inherit (options) package;
      flags = configFlag;
      postWrap = ''
        unit=$out/lib/systemd/user/foot-server.service
        cp "$unit" foot-server.service
        chmod +w foot-server.service
        substituteInPlace foot-server.service \
          --replace-fail "${options.package}/bin/foot" "$out/bin/foot"
        cp --remove-destination foot-server.service "$unit"
      '';
      symlinks = {
        "$out/foot/foot.ini" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "foot.ini" options.settings
          else
            null;
      };
    };

  meta = {
    maintainers = [ "bivsk" ];
  };
}
