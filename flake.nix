{
  description = "Nix flake for NousResearch/hermes-agent — packaged with uv2nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hermes-agent-src = {
      url = "github:NousResearch/hermes-agent/v2026.5.16";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    uv2nix,
    pyproject-nix,
    pyproject-build-systems,
    hermes-agent-src,
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];

      perSystem = {
        pkgs,
        system,
        lib,
        ...
      }: let
        python = pkgs.python313;

        workspace = uv2nix.lib.workspace.loadWorkspace {
          workspaceRoot = hermes-agent-src;
        };

        overlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel";
        };

        overrides = import ./overrides.nix {inherit pkgs lib;};

        pythonSet =
          (pkgs.callPackage pyproject-nix.build.packages {
            inherit python;
          })
          .overrideScope (
            lib.composeManyExtensions [
              pyproject-build-systems.overlays.default
              overlay
              overrides
            ]
          );

        # Build a venv with a given dep selection.
        mkHermesVenv = depGroups:
          pythonSet.mkVirtualEnv "hermes-agent-env" depGroups;

        # Wrap venv → expose CLI entry points under $out/bin.
        mkHermesPkg = {
          name,
          depGroups,
        }:
          pkgs.runCommandLocal name {
            meta = {
              description = "NousResearch hermes-agent (${name})";
              homepage = "https://github.com/NousResearch/hermes-agent";
              license = lib.licenses.mit;
              mainProgram = "hermes";
              platforms = lib.platforms.unix;
            };
            passthru = {
              venv = mkHermesVenv depGroups;
              inherit python;
            };
          } ''
            mkdir -p $out/bin
            for bin in hermes hermes-agent hermes-acp; do
              if [ -x ${mkHermesVenv depGroups}/bin/$bin ]; then
                ln -s ${mkHermesVenv depGroups}/bin/$bin $out/bin/$bin
              fi
            done
          '';
      in {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        packages = {
          default = self.packages.${system}.hermes-agent;

          hermes-agent = mkHermesPkg {
            name = "hermes-agent";
            depGroups = workspace.deps.default;
          };

          hermes-agent-full = mkHermesPkg {
            name = "hermes-agent-full";
            depGroups = workspace.deps.all;
          };
        };

        apps = {
          default = {
            type = "app";
            program = "${self.packages.${system}.hermes-agent}/bin/hermes";
          };
        };

        checks = {
          smoke = pkgs.runCommand "hermes-smoke" {} ''
            ${self.packages.${system}.hermes-agent}/bin/hermes --version > $out
          '';
        };

        formatter = pkgs.alejandra;
      };

      flake = {
        # home-manager module — consumers add this to their hm.modules list.
        homeManagerModules.default = import ./modules/home-manager.nix {
          inherit (self) packages;
        };
      };
    };
}
