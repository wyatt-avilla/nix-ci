# Nix CI

Reusable Nix checks. Formatting is configured through
[treefmt-nix](https://github.com/numtide/treefmt-nix), and local/CI hooks are
generated through [git-hooks.nix](https://github.com/cachix/git-hooks.nix).

The default stack runs:

- `treefmt` with `nixfmt`
- `treefmt` with `prettier` for Markdown and YAML
- `statix`
- `deadnix`

`formatter`, the formatting check, and the pre-commit `treefmt` hook are all
derived from the same `treefmtConfig`. The default formatters are enabled as if
you set `nix-ci.lib.enableFormatting = true;`, and normal `treefmt-nix` options
can override them.

## Example usage

### Flake

```nix
{
  inputs = {
    nix-ci = {
      url = "github:wyatt-avilla/nix-ci";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, nix-ci, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkProject =
        system:
        nix-ci.lib.mkProject {
          pkgs = nixpkgs.legacyPackages.${system};
          src = self;

          treefmtConfig = {
            nix-ci.lib.enableFormatting = true;

            programs.prettier.settings.proseWrap = "always";
          };
        };
    in
    {
      formatter = forAllSystems (system: (mkProject system).formatter);

      checks = forAllSystems (system: (mkProject system).checks);

      devShells = forAllSystems (system: {
        default = (mkProject system).devShell;
      });
    };
}
```

Run all checks with:

```sh
nix flake check
```

Format with:

```sh
nix fmt
```

Entering the dev shell installs the generated pre-commit hooks:

```sh
nix develop
```

### GitHub Action

```yml
name: Nix CI

on:
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]

jobs:
  shared:
    uses: wyatt-avilla/nix-ci/.github/workflows/nix-ci.yml@main
```
