# State Files & Migration

What lives in `dataDir` (= `HERMES_HOME`) — and what's worth preserving when migrating between hosts or restoring from backup.

## Contents of `dataDir`

| Path | Owner | Purpose | Preserve? | Notes |
|---|---|---|---|---|
| `config.yaml` | nix | Generated from `services.hermes-agent.settings` | No | rebuild rewrites it |
| `SOUL.md` | nix | Personality file | No | rebuild rewrites it |
| `.env` | (deprecated) | Pre-sops local secrets | Delete after sops kicks in | secrets now in `EnvironmentFile=` |
| `state.db` | hermes | Main runtime state (sessions, conversations, prefs) | **Yes** | sqlite, 1-5 MB typical |
| `state.db-shm` / `state.db-wal` | hermes | SQLite write-ahead log | No | regenerated |
| `kanban.db` | hermes | Kanban board state | **Yes** | sqlite, ~100 KB |
| `response_store.db` | hermes | Response cache | Yes (optional) | regenerated on miss |
| `sessions/` | hermes | Past conversation history | **Yes** | per-session JSON |
| `memories/` | hermes | Long-term memory entries | **Yes** | wiki provider stores under `wiki/` instead |
| `wiki/` | hermes | Karpathy-style knowledge wiki | **Yes** | markdown notes |
| `skills/` | hermes | Learned skills (markdown + Python) | **Yes** | grows over time, often largest dir |
| `cron/` | hermes | Scheduled tasks | **Yes** | usually empty |
| `hooks/` | hermes | User hooks | **Yes** | usually empty |
| `platforms/` | hermes | Per-platform state | Yes | small |
| `pairing/` | hermes | Device pairing tokens | Yes | small |
| `cache/` | hermes | Generic cache | No | regenerated |
| `audio_cache/` | hermes | STT/TTS audio buffers | No | regenerated |
| `image_cache/` | hermes | Vision tool images | No | regenerated |
| `logs/` | hermes | Runtime logs | No | rotates |
| `lsp/` | hermes | LSP server caches | No | regenerated |
| `sandboxes/` | hermes | Tool sandboxes | No | ephemeral |
| `bin/` | hermes | Lazy-installed CLIs (ripgrep, ffmpeg, node) | No | re-fetched |
| `channel_directory.json` | hermes | Discord/Telegram channel map | Yes | tied to gateway state |
| `gateway_state.json` | hermes | Gateway restart state | Yes | small |
| `models_dev_cache.json` | hermes | models.dev cache | No | regenerated |
| `ollama_cloud_models_cache.json` | hermes | Ollama cloud list | No | regenerated |
| `.skills_prompt_snapshot.json` | hermes | Last skills prompt | No | regenerated |
| `.restart_*` | hermes | Restart bookkeeping | No | regenerated |
| `.update_check` | hermes | Update check timestamp | No | regenerated |
| `feishu_seen_message_ids.json` | hermes | Feishu dedup | Yes | only if you use Feishu |
| `interrupt_debug.log` | hermes | Debug log | No | rotates |

## Minimal backup set

If you only want the irreplaceable bits:

```fish
tar czf hermes-backup-$(date +%Y%m%d).tar.gz \
  -C /var/lib/hermes-agent \
  state.db kanban.db sessions memories wiki skills cron hooks platforms pairing \
  channel_directory.json gateway_state.json
```

## Snapshot via btrfs

`dataDir` lives on a btrfs subvolume (created by the bootstrap). Atomic snapshot:

```fish
sudo btrfs subvolume snapshot -r /var/lib/hermes-agent /var/lib/snapshots/hermes-$(date +%Y%m%d-%H%M)
```

Send/receive to offsite (Voyager) over Tailscale:

```fish
sudo btrfs send /var/lib/snapshots/hermes-20260523-1400 | \
  ssh voyager 'sudo btrfs receive /backup/hermes/'
```

## Migration: Docker → NixOS (Discovery)

Existing Docker container's data dir = `/home/erik/homelab/apps/hermes-agent` (host bind-mount). UID inside container = 10000.

```fish
# stop container
ssh discovery 'sudo systemctl stop podman-compose-hermes-agent.service || docker stop hermes-agent'

# move + chown
ssh discovery 'sudo mv /home/erik/homelab/apps/hermes-agent /var/lib/hermes-agent'
ssh discovery 'sudo chown -R 10000:10000 /var/lib/hermes-agent'

# (optional) promote to btrfs subvolume
# requires the dir to be initially a regular dir on a btrfs filesystem
# safest: snapshot once, then continue using as subvolume on next service start

# deploy NixOS module
sudo nixos-rebuild switch --flake .#discovery --target-host discovery

# verify
ssh discovery 'sudo machinectl status hermes; sudo journalctl -M hermes -u hermes-agent -n 30'
```

All state — sessions, skills, wiki, kanban — preserved.

## Migration: laptop ~/.hermes (legacy) → nix-managed

The laptop's `~/.hermes/` is already the dataDir per the HM module. No migration needed. But the local `.env` is superseded by sops + shell env exports — safe to delete:

```fish
# verify sops + env are working
fish -lc 'env | grep -E "^(OPENAI|HERMES)_"'
# expect: OPENAI_API_KEY, OPENAI_BASE_URL, HERMES_DEFAULT_MODEL

# then delete the .env (it's been superseded)
rm ~/.hermes/.env
```

After this, the laptop CLI uses `$OPENAI_API_KEY` (= Discovery's API_SERVER_KEY) + `$OPENAI_BASE_URL` (= Discovery's API gateway) — no local secrets file needed.

## Per-host data dirs

| Host | dataDir |
|---|---|
| laptop | `/home/erik/.hermes` (per-user, own brain not used for chat — see CLIENT.md) |
| Discovery | `/var/lib/hermes-agent` (system service, the actual production brain) |

Discovery's data is the persistent agent — sessions, skills, wiki grow there. Laptop's `~/.hermes` mostly holds local-only state (history, config) since chat is delegated to Discovery via API.
