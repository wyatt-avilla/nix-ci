{
  description = "Reusable Nix project checks";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    in
    {
      lib = {
        mkFormattingCheck =
          { pkgs, src }:
          pkgs.runCommandLocal "check-formatting"
            {
              buildInputs = [
                pkgs.nixfmt-rfc-style
                pkgs.fd
              ];
            }
            ''
              cd ${src}

              echo "Checking Nix file formatting..."
              format_errors=0

              for file in $(fd -e nix . --type f); do
                echo "Checking $file..."
                
                if ! nixfmt --check "$file" 2>/dev/null; then
                  echo "❌ $file is not properly formatted"
                  format_errors=$((format_errors + 1))
                else
                  echo "✅ $file is properly formatted"
                fi
              done

              if [ $format_errors -eq 0 ]; then
                echo "All files are properly formatted!"
                mkdir $out
              else
                echo "Found $format_errors formatting issues"
                echo "Run 'nixfmt **/*.nix' to fix formatting issues"
                exit 1
              fi
            '';

        mkLintingCheck =
          { pkgs, src }:
          pkgs.runCommandLocal "check-linting" { buildInputs = [ pkgs.statix ]; } ''
            cd ${src}

            echo "Running statix linter..."
            if statix check .; then
              echo "✅ No linting issues found"
              mkdir $out
            else
              echo "❌ Linting issues found"
              echo "Run 'statix fix .' to fix some issues automatically"
              exit 1
            fi
          '';

        mkDeadCodeCheck =
          { pkgs, src }:
          pkgs.runCommandLocal "check-dead-code" { buildInputs = [ pkgs.deadnix ]; } ''
            cd ${src}

            echo "Checking for dead code..."
            if deadnix .; then
              echo "✅ No dead code found"
              mkdir $out
            else
              echo "❌ Dead code found"
              echo "Run 'deadnix --edit .' to remove dead code"
              exit 1
            fi
          '';

        mkCheckDevShell =
          {
            pkgs,
            extraPackages ? [ ],
          }:
          pkgs.mkShell {
            packages =
              with pkgs;
              [
                nixfmt-rfc-style
                statix
                deadnix
                fd
              ]
              ++ extraPackages;

            shellHook = ''
              echo "Nix project check tools available:"
              echo "  nixfmt **/*.nix     - Format all Nix files"
              echo "  statix check .      - Run linter"
              echo "  statix fix .        - Auto-fix linting issues"
              echo "  deadnix --edit .    - Remove dead code"
              echo ""
              echo "Available flake checks:"
              echo "  nix flake check .#formatting"
              echo "  nix flake check .#linting"
              echo "  nix flake check .#eval-check"
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
            paths = with pkgs; [
              nixfmt-rfc-style
              statix
              deadnix
              fd
            ];
          };
        }
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
        {
          formatting = self.lib.mkFormattingCheck {
            src = self;
            inherit pkgs;
          };

          linting = self.lib.mkLintingCheck {
            src = self;
            inherit pkgs;
          };

          dead-code = self.lib.mkDeadCodeCheck {
            src = self;
            inherit pkgs;
          };
        }
      );
    };
}
