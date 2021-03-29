{
  requirements,  # content from a requirements.txt file
  python,  # python from nixpkgs as base for overlay
  pkgs,
  tests ? false,  # disable tests wherever possible
  overrides ? [],
  providers ? {},  # re-order to change provider priority or remove providers
  pypiData,
  _providerDefaults ? with builtins; fromTOML (readFile ../provider_defaults.toml)
}:
let
  nixpkgs_json = import ./nixpkgs-json.nix {
    inherit overrides pkgs python;
  };
  builder_python = pkgs.pkgsBuildHost.python37.withPackages(ps:
    (pkgs.lib.attrValues (import ./python-deps.nix {python = pkgs.python37; fetchurl = pkgs.fetchurl; }))
  );
  src = ./../../.;
  db_and_fetcher = import ./deps-db-and-fetcher.nix {
    inherit pkgs;
    deps_db_src = pypiData;
  };
  providers_json = builtins.toJSON ( _providerDefaults // providers);
  mach_nix_file = pkgs.runCommand "mach_nix_file"
    { buildInputs = [ src builder_python db_and_fetcher.pypi_deps_db_src];
      inherit nixpkgs_json requirements;
      inherit (db_and_fetcher) pypi_deps_db_src pypi_fetcher_commit pypi_fetcher_sha256;
      disable_checks = ! tests;
      providers = providers_json;
      py_ver_str = python.version;
    }
    ''
      mkdir -p $out/share
      export out_file=$out/share/mach_nix_file.nix
      export PYTHONPATH=${src}
      ${builder_python}/bin/python ${src}/mach_nix/generate.py
    '';
in
# single file derivation containing $out/share/mach_nix_file.nix
mach_nix_file
