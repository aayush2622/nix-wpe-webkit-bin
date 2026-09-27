{
  description = "Prebuilt WPE WebKit for Nix - binaries published via GitHub Releases so consumers don't have to build WebKit from source themselves";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  nixConfig = {
    extra-substituters = [ "https://wpewebkit-bin.cachix.org" ];
    extra-trusted-public-keys = [
      "wpewebkit-bin.cachix.org-1:/ALEUaA8yEUbLGwgyJ+JT5UXxkCvaDakfve9zVROGf8="
    ];
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      versions = builtins.fromJSON (builtins.readFile ./versions.json);
    in
    {
      packages = forAllSystems (
        system:
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
            nativeBuildInputs = [
              pkgs.gnutar
              pkgs.gzip
            ];
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

              # 2. CI builds the tarball with `cp -rL`, which dereferences the
              #    library symlinks: libWPEWebKit-2.0.so and .so.1 arrive as full
              #    173 MB copies of .so.1.9.7 rather than links to it. Restore the
              #    symlinks before patching. That takes the unpacked output from
              #    569 MB down to 216 MB, and -- because `grep -r`/`sed` then see
              #    the 173 MB library once instead of three times -- turns the
              #    rewrite below from ~1.6 GB of I/O into ~0.5 GB.
              for real in $out/lib/*.so.*; do
                [ -f "$real" ] && [ ! -L "$real" ] || continue
                d="''${real%/*}" b="''${real##*/}" alias="''${real##*/}"
                while alias="''${alias%.*}"; do
                  case "$alias" in *.so | *.so.*) ;; *) break ;; esac
                  if [ -f "$d/$alias" ] && [ ! -L "$d/$alias" ] \
                     && cmp -s "$real" "$d/$alias"; then
                    ln -sf "$b" "$d/$alias"
                  fi
                  case "$alias" in *.so) break ;; esac
                done
              done

              # 3. libWPEWebKit hardcodes its own libexec path (the helper
              #    processes) from the CI build. Same-length hash, so
              #    rewrite it in place to this package's own store path.
              #    `grep -r` does not descend into the symlinks made above, so
              #    the big library is scanned and rewritten exactly once.
              if [ -n "$ci" ]; then
                me="$(basename $out | cut -c1-32)"
                grep -rlF "$ci" $out | while read -r f; do
                  sed -i "s/$ci/$me/g" "$f"
                done
              fi

              # 4. The .pc files point includedir at CI's `-dev` output, which
              #    this single-output repack never produces. Any consumer that
              #    builds its PKG_CONFIG_PATH from this package then hands
              #    CMake a non-existent include dir and fails to configure.
              #    Point includedir at our own headers.
              sed -i "s|^includedir=.*|includedir=$out/include|" \
                $out/lib/pkgconfig/*.pc

              # 5. The merge step dropped executable bits.
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
