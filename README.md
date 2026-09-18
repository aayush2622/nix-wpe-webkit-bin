# nix-wpe-webkit-bin

Prebuilt [WPE WebKit](https://wpewebkit.org) binaries for Nix, published as
GitHub Releases so you don't have to build WebKit from source yourself.

`wpe-webkit-2.0` isn't packaged in nixpkgs at all, and a from-scratch build
of it routinely takes multiple hours. This flake builds it once in CI and
publishes the result as a release tarball; consuming flakes fetch that
tarball instead of rebuilding, dropping the install time to seconds.

## Usage

```nix
{
  inputs.nix-wpe-webkit-bin.url = "github:aayush2622/nix-wpe-webkit-bin";

  outputs = { self, nixpkgs, nix-wpe-webkit-bin, ... }: {
    # nix-wpe-webkit-bin.packages.${system}.default
    # resolves to a prebuilt fetch when one exists for your system,
    # falling back to a from-source build otherwise. Either way you get
    # the same wpe-webkit-2.0 pkg-config module and libraries.
  };
}
```

Or directly:

```
nix build github:aayush2622/nix-wpe-webkit-bin
```

## Outputs

| Output | Behavior |
| --- | --- |
| `packages.<system>.default` / `.wpewebkit` | Prebuilt fetch when `versions.json` has an entry for `<system>`, from-source build otherwise. This is the one you want. |
| `packages.<system>.wpewebkit-source` | Always builds from source, regardless of what's published. Mainly useful for CI itself and for verifying a release before it's cut. |

## Supported systems

Currently `x86_64-linux` only. `aarch64-linux` is declared in the flake so
the output shape is consistent, but has no CI job publishing a prebuilt for
it yet - it always builds from source until one is added. PRs adding that
job are welcome.

## Where `package.nix` comes from

Vendored from [eval-exec/nix-wpe-webkit](https://github.com/eval-exec/nix-wpe-webkit),
the only known working from-source derivation for `wpe-webkit-2.0` at the
time this repo was created. It's a plain copy, not a fork with local
patches - if upstream fixes something, that fix needs to be re-vendored
here by hand (there's no automation for this yet).

## How the CI publishing works

`.github/workflows/build.yml` runs on push to `main` (when `package.nix`,
`flake.nix`, or `flake.lock` change), on a weekly schedule, and on manual
dispatch. Each run:

1. Builds `wpewebkit-source` for real, from scratch.
2. Merges every output (`out`, `dev`, `devdoc`) into one tree and tars it -
   a single-output tarball would be missing `dev`'s headers and
   `lib/pkgconfig/wpe-webkit-2.0.pc`, which is exactly the bug an earlier
   version of this workflow shipped with.
3. Uploads that tarball to a GitHub Release tagged with the WebKit version.
4. Computes the release asset's Nix-compatible hash and commits it, along
   with the download URL, into `versions.json`.

`flake.nix` reads `versions.json` at eval time; if it has an entry for your
system, `packages.<system>.default` fetches and unpacks that tarball via
`fetchurl` instead of building. No entry yet (a fresh clone before the
first CI run ever completes, or a new system nobody's published for) means
it transparently falls back to `wpewebkit-source` - slower, but correct.

## Verifying a release actually works

Don't just trust that CI went green - a successful build can still produce
a tarball that's missing files a real consumer needs. Before trusting a new
`versions.json` entry:

```
nix build github:aayush2622/nix-wpe-webkit-bin
ls result/lib/pkgconfig/wpe-webkit-2.0.pc   # must exist
```

If that file is missing, the tarball is incomplete - see step 2 above for
why that happens and how the workflow guards against it now.
