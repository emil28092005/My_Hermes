---
name: hermes-workspace-setup
description: "Install, configure, and run Hermes Workspace UI (outsourc-e/hermes-workspace) with external access and common bugfixes."
version: 1.0.0
author: Hermes Agent
metadata:
  hermes:
    tags: [hermes, workspace, devops, local-server, gateway, ui-setup, vite]
---

# Hermes Workspace UI Setup

Install and run the Project Workspace UI (`outsourc-e/hermes-workspace`) for Hermes Agent — a web dashboard that connects to the Gateway HTTP API.

## What It Does

- Clones `outsourc-e/hermes-workspace`
- Installs dependencies with `pnpm`
- Links bundled skills to `~/.hermes/skills/`
- Configures `.env` for external access (`HOST=0.0.0.0`)
- Fixes known frontend bug (`HermesOnboarding is not defined`)

## Prerequisites

- **Node 22+**: `node -v` must report v22+
- **pnpm**: `corepack enable` or `npm install -g pnpm`
- **Hermes Agent**: already installed (`hermes` on PATH)
- **Git**: for cloning the repo

## Install Steps

### 1. Clone the repo

```bash
git clone https://github.com/outsourc-e/hermes-workspace.git ~/hermes-workspace
cd ~/hermes-workspace
```

### 2. Configure `.env`

```bash
cp .env.example .env
```

Required values in `~/hermes-workspace/.env`:
```ini
# Gateway HTTP API endpoint
HERMES_API_URL=http://127.0.0.1:8642
VITE_HERMES_API_URL=http://127.0.0.1:8642

# Allow external access (host machine or LAN)
HOST=0.0.0.0
```

### 3. Install dependencies

```bash
pnpm install --no-frozen-lockfile
```

### 4. Link bundled skills

```bash
for skill_path in ~/hermes-workspace/skills/*/; do
  skill_name=$(basename "$skill_path")
  target="$HOME/.hermes/skills/$skill_name"
  [ -e "$target" ] || ln -sf "$skill_path" "$target"
done
```

### 5. Fix onboarding bug (if present)

**File**: `src/routes/__root.tsx`

```bash
sed -i 's/HermesOnboarding/ClaudeOnboarding/g' src/routes/__root.tsx
```

Bug: component imported as `ClaudeOnboarding` but used as `HermesOnboarding` — leftover from rename.

## Run the Workspace

### Terminal 1: Hermes Gateway

The Gateway must be running first. It provides the HTTP REST API on port 8642.

```bash
hermes gateway run
```

**Or** via systemd (safer — doesn't kill Telegram session):

```bash
systemctl --user start hermes-gateway.service
```

**Important**: The Gateway HTTP API is **opt-in**. Verify `API_SERVER_ENABLED=true` in `~/.hermes/.env`:

```ini
API_SERVER_ENABLED=true
```

> ⚠️ Adding or changing this requires a Gateway restart.

### Terminal 2: Workspace UI

```bash
cd ~/hermes-workspace && HOST=0.0.0.0 PORT=3000 pnpm dev
```

- UI runs on `http://0.0.0.0:3000` (all interfaces)
- Connects to Gateway on `http://127.0.0.1:8642`

## Verify Everything Works

```bash
# Gateway HTTP API health
curl -s http://127.0.0.1:8642/health
# Expected: {"status": "ok", "platform": "hermes-agent"}

# Workspace UI is responding
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000
# Expected: 200
```

## Access URLs

| Endpoint | URL | Who needs it |
|----------|-----|-------------|
| Gateway API | `http://127.0.0.1:8642` | Workspace UI (internal) |
| Workspace UI (local) | `http://localhost:3000` | Browser on same machine |
| Workspace UI (LAN) | `http://VM_IP:3000` | Browser on host machine |

Get VM IP: `hostname -I` → e.g. `http://192.168.122.31:3000`

## Common Issues

**Issue: Workspace UI shows "disconnected" or blank**

Cause: `HERMES_API_URL` not set in workspace `.env`, or Gateway API not enabled.

Fix:
```bash
# 1. Check workspace .env
grep HERMES_API_URL ~/hermes-workspace/.env
# 2. Check gateway .env
grep API_SERVER_ENABLED ~/.hermes/.env
# 3. Restart both
```

**Issue: Gateway restart kills Telegram**

Cause: `hermes gateway restart` stops and restarts the whole gateway process.

Fix: Use systemd instead:
```bash
systemctl --user restart hermes-gateway.service
```
This restarts the service while reconnecting messaging platforms.

**Issue: Workspace UI not accessible from host machine**

Cause: `HOST=127.0.0.1` in workspace `.env`.

Fix: Set `HOST=0.0.0.0` and restart the dev server.

## Pitfalls

1. **Gateway restart = session disconnect** — When connected via Telegram/Discord, `hermes gateway restart` severs the conversation. Use `systemctl --user restart hermes-gateway.service`.
2. **HTTP API is opt-in** — Without `API_SERVER_ENABLED=true`, `curl http://127.0.0.1:8642/health` returns nothing even though the gateway is running.
3. **Vite dev server only** — `pnpm dev` is for development. For production, build and serve with nginx/caddy.
4. **workspace `.env` ≠ hermes `.env`** — Two separate files with different purposes. Workspace `.env` points `HERMES_API_URL` at the gateway.
