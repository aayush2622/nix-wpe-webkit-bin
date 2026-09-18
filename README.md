# nix-wpe-webkit-bin

Prebuilt [WPE WebKit](https://wpewebkit.org) binaries for Nix, published as
GitHub Releases so you don't have to build WebKit from source yourself
(a from-scratch build takes hours).

The `package.nix` here is vendored from
[eval-exec/nix-wpe-webkit](https://github.com/eval-exec/nix-wpe-webkit) - the
only known working from-source derivation for `wpe-webkit-2.0`, which isn't
packaged in nixpkgs at all. A GitHub Actions workflow builds it and publishes
the result as a release tarball; `flake.nix` fetches that tarball instead of
building when one is available for your system.

## Usage

```nix
{
  inputs.nix-wpe-webkit-bin.url = "github:aayush262/nix-wpe-webkit-bin";

  outputs = { self, nixpkgs, nix-wpe-webkit-bin, ... }: {
    # nix-wpe-webkit-bin.packages.${system}.default
    # resolves to a prebuilt fetch when one exists for that system,
    # falling back to a from-source build otherwise.
  };
}
```

Or directly:

```
nix build github:aayush262/nix-wpe-webkit-bin
```

## Outputs

- `packages.<system>.default` / `.wpewebkit` - prebuilt when available, source
  build otherwise.
- `packages.<system>.wpewebkit-source` - always builds from source.

## Supported systems

Currently `x86_64-linux`. `aarch64-linux` is declared in the flake but has no
CI job yet, so it always builds from source until one is added.

## How the CI publishing works

On push to `main` (when `package.nix`/`flake.nix`/`flake.lock` change), on a
weekly schedule, or on manual dispatch: `.github/workflows/build.yml` builds
`wpewebkit-source`, tars the merged output tree, uploads it to a GitHub
Release tagged with the WebKit version, and commits the release URL + Nix
hash back into `versions.json`. `flake.nix` reads `versions.json` to decide
whether a prebuilt fetch is available for the current system.
