# Nix CI

Runs linting via [statix](https://github.com/oppiliappan/statix), formatting
checks via [nixfmt](https://github.com/NixOS/nixfmt) and a buld check with
`nix flake check`

## Example usage

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

### Precommit hook

```yml
repos:
  - repo: https://github.com/wyatt-avilla/nix-ci
    rev: main
    hooks:
      - id: nixfmt
      - id: statix
      - id: nix-flake-check
```
