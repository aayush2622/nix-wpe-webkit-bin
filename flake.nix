{
  description = "Prebuilt WPE WebKit for Nix - binaries published via GitHub Releases so consumers don't have to build WebKit from source themselves";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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

              # The tarball is a plain merge of CI's outputs, so it needs
              # three fixes to be usable from a different store:
              # 1. nix-support/propagated-build-inputs lists CI-only store
              #    paths, which make every consumer's stdenv fail with
              #    "build input ... does not exist". Read the CI's own
              #    hash out of it first, then drop the directory.
              ci="$(sed -E 's#.*/nix/store/([a-z0-9]{32})-.*#\1#' $out/nix-support/propagated-build-inputs 2>/dev/null | head -1)"
              rm -rf $out/nix-support

              # 2. libWPEWebKit hardcodes its own libexec path (the helper
              #    processes) from the CI build. Same-length hash, so
              #    rewrite it in place to this package's own store path.
              if [ -n "$ci" ]; then
                me="$(basename $out | cut -c1-32)"
                grep -rlF "$ci" $out | while read -r f; do
                  sed -i "s/$ci/$me/g" "$f"
                done
              fi

              # 3. The merge step dropped executable bits.
              chmod +x $out/libexec/wpe-webkit-2.0/* $out/bin/* 2>/dev/null || true
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
