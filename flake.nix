{
  description = "Reusable Nix project checks";

  inputs = {
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      git-hooks,
      nixpkgs,
      treefmt-nix,
    }:
    let
      inherit (nixpkgs) lib;
      defaultTreefmtConfig =
        { config, lib, ... }:
        let
          cfg = config.nix-ci.lib;
        in
        {
          options.nix-ci.lib.enableFormatting = lib.mkEnableOption "the default nix-ci formatters";

          config = lib.mkIf cfg.enableFormatting {
            projectRootFile = lib.mkDefault "flake.nix";

            programs = {
              nixfmt.enable = lib.mkDefault true;
              prettier = {
                enable = lib.mkDefault true;
                includes = lib.mkOverride 900 [
                  "*.md"
                  "*.mdx"
                  "*.markdown"
                  "*.yaml"
                  "*.yml"
                ];
              };
            };
          };
        };
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    in
    {
      lib = {
        inherit defaultTreefmtConfig;

        enableFormatting = {
          nix-ci.lib.enableFormatting = true;
        };

        mkTreefmt =
          {
            pkgs,
            treefmtConfig ? { },
          }:
          treefmt-nix.lib.evalModule pkgs {
            imports = [
              self.lib.defaultTreefmtConfig
              { nix-ci.lib.enableFormatting = lib.mkDefault true; }
              treefmtConfig
            ];
          };

        mkPreCommitCheck =
          {
            pkgs,
            src,
            treefmtConfig ? { },
            treefmt ? self.lib.mkTreefmt { inherit pkgs treefmtConfig; },
            hooks ? { },
            tools ? { inherit (pkgs) deadnix statix; },
            imports ? [ ],
          }:
          let
            inherit (pkgs.stdenv.hostPlatform) system;
            defaultHooks = {
              deadnix.enable = true;
              statix.enable = true;

              treefmt = {
                enable = true;
                packageOverrides.treefmt = treefmt.config.build.wrapper;
              };
            };
          in
          git-hooks.lib.${system}.run {
            inherit imports src tools;
            hooks = lib.recursiveUpdate defaultHooks hooks;
          };

        mkChecks =
          {
            pkgs,
            src,
            treefmtConfig ? { },
            treefmt ? self.lib.mkTreefmt { inherit pkgs treefmtConfig; },
            hooks ? { },
            tools ? { inherit (pkgs) deadnix statix; },
            imports ? [ ],
          }:
          {
            formatting = treefmt.config.build.check src;
            pre-commit-check = self.lib.mkPreCommitCheck {
              inherit
                hooks
                imports
                pkgs
                src
                tools
                treefmt
                treefmtConfig
                ;
            };
          };

        mkProject =
          {
            pkgs,
            src,
            treefmtConfig ? { },
            hooks ? { },
            tools ? { inherit (pkgs) deadnix statix; },
            imports ? [ ],
            extraPackages ? [ ],
          }:
          let
            treefmt = self.lib.mkTreefmt { inherit pkgs treefmtConfig; };
            checks = self.lib.mkChecks {
              inherit
                hooks
                imports
                pkgs
                src
                tools
                treefmt
                treefmtConfig
                ;
            };
          in
          {
            formatter = treefmt.config.build.wrapper;
            inherit checks;
            devShell = self.lib.mkCheckDevShell {
              inherit extraPackages pkgs;
              preCommitCheck = checks.pre-commit-check;
            };
          };

        mkCheckDevShell =
          {
            pkgs,
            extraPackages ? [ ],
            preCommitCheck ? self.checks.${pkgs.stdenv.hostPlatform.system}.pre-commit-check,
          }:
          pkgs.mkShell {
            packages = preCommitCheck.enabledPackages ++ extraPackages;

            shellHook = ''
              ${preCommitCheck.shellHook}
            '';
          };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          check-tools = pkgs.buildEnv {
            name = "nix-check-tools";
            paths = self.checks.${system}.pre-commit-check.enabledPackages ++ [ self.formatter.${system} ];
          };
        }
      );

      formatter = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        (self.lib.mkTreefmt { inherit pkgs; }).config.build.wrapper
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = self.lib.mkCheckDevShell { inherit pkgs; };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        self.lib.mkChecks {
          inherit pkgs;
          src = self;
        }
      );
    };
}
