# Memory

## User Preferences

- **Name:** Emil Shanaty
- **Platform:** Telegram
- **Home Channels:** telegram: Home (ID: 1306814032)

## Workflow Configuration

### Architecture: Claude Code + Hermes Orchestrator

**Concept:** Hermes runs on kimi-k2.6 API credits. Claude Code has its own subscription billing. To preserve API credits, all token-intensive implementation work MUST be delegated to Claude Code via `claude -p` terminal commands.

**Roles:**
- **Claude Code** (`claude -p`) → Implementer. ALL code generation: HTML/CSS/JS, system setup scripts, installations, file writing, debugging
- **Hermes** (kimi-k2.6) → Orchestrator. Planning, prompt crafting, delegation, verification (curl/ls/pgrep), port/server management, tunneling

**Rules:**
- Hermes NEVER writes large HTML/CSS/JS files via `write_file`
- Hermes NEVER generates code via Python string literals in `execute_code`
- Hermes NEVER patches code files directly to fix bugs — re-delegate to Claude Code
- Hermes DO: plan → delegate to Claude → verify with shell commands → manage servers

## Environment Details

- **OS:** Linux
- **Python:** 3.11.15 (uv-managed)
- **Claude Code:** v2.1.126 (`claude --version`)
- **VPN:** Active (requires tunneling for local network sharing)
- **Local IP:** 192.168.122.31 (VPN-isolated, not accessible from LAN)

## Proven Pipelines

### Multi-Site Localhost Pipeline
1. Plan N website variants with Claude Code prompts
2. Delegate generation: `claude -p "Create..." --allowedTools Read,Write,Bash --max-turns 15`
3. Verify outputs with `find` and `ls`
4. Clean ports: `lsof -i :PORT -t | head -1` + `kill`
5. Spawn servers: `terminal(background=true, workdir="DIR", command="python3 -m http.server PORT --bind 127.0.0.1")`
6. Verify with `curl`
7. If VPN blocks LAN → use `cloudflared tunnel --url http://127.0.0.1:PORT > /tmp/tunnel.log 2>&1`
8. Extract URL from log after 3-5 seconds

### Cloudflare Tunnel Quick Setup
```bash
curl -sLO https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cloudflared-linux-amd64 && sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
cloudflared tunnel --url http://127.0.0.1:PORT > /tmp/tunnel.log 2>&1
# Wait 3s, then: grep -oP 'https://[^\s]+\.trycloudflare\.com' /tmp/tunnel.log
```

## Lessons Learned

- **Port conflicts:** Always run cleanup loop before spawning servers. `Address already in use` is the #1 error.
- **Working directory:** `python3 -m http.server` serves from CWD. Always set `workdir` explicitly. Use `readlink /proc/$PID/cwd` to debug.
- **Hermes terminal background:** Use `background=true`, never `&` or `nohup`. Hermes rejects foreground backgrounding.
- **Process output:** Hermes `process log` often returns empty. Always redirect to file: `command > /tmp/file.log 2>&1`, then `cat`.
- **Cloudflare Tunnel ephemeral URLs:** Change on every restart. No uptime guarantee. Fine for demos.
- **Claude Code timeouts:** If `claude -p` times out after 120-180s, check partial results with `find`, then continue with remaining prompts.
