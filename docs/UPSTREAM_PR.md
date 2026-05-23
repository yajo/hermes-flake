# Upstream PR Plan

Plan for contributing this flake back to [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent).

## When to upstream

After:
- [ ] 2+ weeks stable use in `desktop-nixos`
- [ ] CI green across `x86_64-linux` + `aarch64-linux`
- [ ] At least one upstream version bump applied via this flake without breaking
- [ ] Cachix cache populated and usable

## Pre-PR

1. Open issue on `NousResearch/hermes-agent` titled `feat: nix flake for reproducible installs?` — gauge interest before sinking PR review time. Link to this flake's CI and to `nix run github:ErikBPF/hermes-flake -- --version` working.
2. Discuss in their Discord if more responsive than issues.

## PR Structure

Minimal-invasion proposal: add `nix/` subdir + top-level `flake.nix` only. No changes to Python code, pyproject.toml, or existing CI.

```
hermes-agent/
├── flake.nix                  # new — re-exports nix/
├── flake.lock                 # new
├── nix/
│   ├── default.nix            # derivation logic
│   ├── overrides.nix          # C-ext deps
│   └── home-manager.nix       # HM module
├── .github/workflows/nix.yml  # new — separate from existing Python CI
└── README.md                  # add nix-install section
```

## PR Title

`feat: add nix flake for reproducible installs`

## PR Body

```markdown
## Summary
Adds first-class Nix support via uv2nix. Same `uv.lock`, same versions, sandboxed builds.

```bash
nix run github:NousResearch/hermes-agent -- --version
```

Or as a home-manager module:

```nix
inputs.hermes-agent.url = "github:NousResearch/hermes-agent";
home.packages = [inputs.hermes-agent.packages.${pkgs.system}.default];
```

## What's added
- `flake.nix` — uv2nix-based derivation, reads `uv.lock` as-is
- `nix/overrides.nix` — minimal C-ext fixes (portaudio for voice, libsndfile for whisper)
- `nix/home-manager.nix` — HM module with config dir / data dir / secrets-file options
- `.github/workflows/nix.yml` — build matrix (linux only initially)

## What's NOT changed
- No changes to Python code
- No changes to `pyproject.toml`
- No changes to `uv.lock`
- Existing CI untouched

## Why
1. NixOS users currently fork or maintain out-of-tree flakes (e.g. ErikBPF/hermes-flake — battle-tested for N weeks)
2. Reproducible: same versions across machines, sandboxed builds, no system Python pollution
3. Discoverable: `nix run github:NousResearch/hermes-agent` works for ~10k+ NixOS users

## Maintenance burden
Minimal. Lockfile auto-tracks `uv.lock`. New override only needed if a Python dep gains a native build requirement — historically rare. I'd volunteer to maintain the nix dir.

## Tested on
- x86_64-linux (NixOS 26.05)
- aarch64-linux (CI)
- Reference impl: github:ErikBPF/hermes-flake — green for N weeks
```

## Files Diff (sketch)

The PR submits the four files above plus README addition:

````markdown
## Install via Nix

```bash
nix run github:NousResearch/hermes-agent
```

See [`nix/README.md`](nix/README.md) for module options.
````

## Worst Case

Maintainer says no. Outcome: zero work wasted, standalone repo continues serving NixOS users. Update README to note "official nix flake declined — use ErikBPF/hermes-flake."

## Best Case

Merged. Archive `hermes-flake` with redirect notice. Continue contributing nix dir directly upstream.

## Communication

- Be deferential, not entitled. Many Python maintainers reject language-specific tooling.
- Offer to handle all nix questions/issues so it doesn't burden core maintainers.
- Don't argue if rejected. Take the L, keep the standalone.
