{
  description = "Prebuilt WPE WebKit for Nix - binaries published via GitHub Releases so consumers don't have to build WebKit from source themselves";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/eaad089433ca2bb662274377d33df3d0e51ef28b";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      versions = builtins.fromJSON (builtins.readFile ./versions.json);
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          source = pkgs.callPackage ./package.nix { };
          prebuiltInfo = versions.${system} or null;

          prebuilt = pkgs.stdenvNoCC.mkDerivation {
            pname = "wpewebkit";
            version = versions.version;
            src = pkgs.fetchurl {
              url = prebuiltInfo.url;
              hash = prebuiltInfo.hash;
            };
            dontUnpack = true;
            nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
            installPhase = ''
              mkdir -p $out
              tar -xzf $src -C $out
            '';
            meta = source.meta;
          };

          wpewebkit = if prebuiltInfo != null then prebuilt else source;
        in
        {
          default = wpewebkit;
          inherit wpewebkit;
          wpewebkit-source = source;
        }
      );
    };
}
