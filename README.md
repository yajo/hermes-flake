# hermes-flake

Nix flake for [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent).

Tracks upstream `v2026.5.16` (v0.14.0). MIT licensed.

## Quick install

```bash
nix run github:ErikBPF/hermes-flake -- --help
```

## Skip builds

CI publishes to GitHub Actions cache via [magic-nix-cache](https://github.com/DeterminateSystems/magic-nix-cache-action). Pull-through happens automatically when you `nix build` against this flake — no client setup required for the latest `main` build artifacts that fit GitHub's free 10GB cache.

For dedicated binary substitution, set up [Garnix](https://garnix.io) (free for public repos) or self-host [Attic](https://github.com/zhaofengli/attic).

## As home-manager module

```nix
{
  inputs.hermes-flake.url = "github:ErikBPF/hermes-flake";

  outputs = { home-manager, hermes-flake, ... }: {
    homeConfigurations.you = home-manager.lib.homeManagerConfiguration {
      modules = [
        hermes-flake.homeManagerModules.default
        {
          programs.hermes-agent = {
            enable = true;
            configDir = "~/.config/hermes";
            secrets.anthropicApiKeyFile = "/run/secrets/hermes/anthropic";
            extraEnvironment.HERMES_DEFAULT_MODEL = "claude-opus-4-7";
          };
        }
      ];
    };
  };
}
```

## Variants

| Output | Extras |
|---|---|
| `hermes-agent` | base only |
| `hermes-agent-full` | all upstream extras |

## Options (home-manager)

| Option | Default | Purpose |
|---|---|---|
| `enable` | false | Install hermes |
| `package` | `packages.hermes-agent` | Variant to install |
| `configDir` | `~/.config/hermes` | `$HERMES_CONFIG_DIR` |
| `dataDir` | `~/.local/share/hermes` | `$HERMES_DATA_DIR` |
| `cacheDir` | `~/.cache/hermes` | `$HERMES_CACHE_DIR` |
| `secrets.openaiApiKeyFile` | null | Path to sops-rendered key |
| `secrets.anthropicApiKeyFile` | null | Path to sops-rendered key |
| `secrets.openrouterApiKeyFile` | null | Path to sops-rendered key |
| `secrets.extraKeyFiles` | `{}` | `{ VAR = path; }` map |
| `extraEnvironment` | `{}` | Static env vars |
| `systemdService.enable` | false | Run as user systemd service |
| `systemdService.extraArgs` | `[]` | Args appended to `hermes` |

## sops-nix Integration

Define secrets in sops.yaml, render to `/run/secrets/hermes/*`, point hermes-agent at the rendered paths.

```nix
sops.secrets."hermes/anthropic" = {
  owner = config.users.users.erik.name;
  mode = "0400";
};

programs.hermes-agent.secrets.anthropicApiKeyFile =
  config.sops.secrets."hermes/anthropic".path;
```

## Status

| Layer | x86_64-linux | aarch64-linux | aarch64-darwin |
|---|---|---|---|
| Build | ⏳ | ⏳ | ⏳ |
| Smoke test | ⏳ | ⏳ | ⏳ |

(Badges arrive once CI is wired.)

## Roadmap

- [ ] First green build (base variant)
- [ ] CI + cachix
- [ ] Upstream PR draft (see `docs/UPSTREAM_PR.md`)
- [ ] Multi-variant outputs (`voice`, `messaging`, `web`)
- [ ] NixOS module (system-wide service)
- [ ] VM integration test

## License

MIT — mirrors hermes-agent.
