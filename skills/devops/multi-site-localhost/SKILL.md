---
name: multi-site-localhost
description: "Generate multiple static websites via Claude Code and serve each on its own local port for comparison."
version: 1.2.0
author: Hermes Agent
metadata:
  hermes:
    tags: [local-server, web-dev, prototyping, claude-code, showcasing, python-http-server, orchestration]
---

# Multi-Site Localhost Pipeline (Claude Code + Hermes Orchestrator)

## Architecture

| Role | Tool | Responsibility |
|------|------|---------------|
| **Implementer** | **Claude Code** (`claude -p`) | ALL code generation: HTML/CSS/JS, system setup scripts, installations, file writing |
| **Orchestrator** | **Hermes** (kimi-k2.6) | Planning, prompt crafting, delegation, verification (curl/ls/pgrep), port/server management |

**Why this split:**
- Claude Code has its own subscription billing — use it for expensive, token-intensive implementation work
- Hermes runs on kimi API credits — keep it cheap by only doing planning, delegation, and lightweight verification
- Hermes NEVER writes large HTML/CSS/JS files directly via `write_file` or string literals in `execute_code`

---

## Rules for Hermes (Orchestrator)

### ✅ DO (Cheap, Fast)
- Plan tasks and site variants
- Craft detailed, self-contained prompts for Claude Code
- Delegate file creation to `claude -p` with `--allowedTools 'Read,Write,Bash'`
- Verify Claude's output with `ls`, `du`, `curl`, `pgrep` — lightweight shell commands
- Manage port cleanup: `lsof -i :PORT -t | head -1` then `kill`
- Spawn `python3 -m http.server` with `background=true` and explicit `workdir`
- Read log files with `cat /tmp/...log`
- Tunnel with `cloudflared` via simple shell commands

### ❌ NEVER DO (Token-Expensive)
- Write multi-hundred-line HTML files via `write_file`
- Generate CSS/JS via Python string literals in `execute_code`
- Do actual "coding" — only orchestration and system glue
- Attempt to fix code bugs by patching files directly — delegate fix to Claude Code

---

## Prerequisites

- **Claude Code installed:** `claude --version` (v2.x+)
- **Python 3:** for `python3 -m http.server`
- **Optional:** `cloudflared` binary in PATH (for VPN tunneling)

---

## Pipeline Steps

### Step 1: Hermes Plans

Analyze the user's request and decide:
- How many site variants?
- What visual styles?
- Directory structure
- Port assignments

### Step 2: Hermes Crafts Claude Prompt

Build a detailed, self-contained prompt. Every prompt must include:
- Exact output paths (`~/Desktop/showcase/variant/index.html`)
- Requirements (embedded CSS/JS, responsive, animations)
- Content skeleton (sections, placeholder data)
- The instruction: "Print the file tree when done"

### Step 3: Hermes Delegates to Claude Code

Generate sites ONE at a time (or in parallel via separate `terminal` calls) using Claude Code's print mode:

```
terminal(
  command='claude -p "Create a clean minimalist resume landing page at ~/Desktop/showcase/minimalist/index.html. Single self-contained HTML with embedded CSS/JS. Include sections: hero, about, experience, skills, contact. Realistic content: Alex Morgan, Product Designer / Full Stack Dev, experience at Stripe, Figma, Vercel. Responsive, smooth scroll, subtle animations. External dependencies: Google Fonts CDN only. Print the file tree when done." --allowedTools Read,Write,Bash --max-turns 15',
  timeout=120
)
```

**Critical flags:**
- `--max-turns 15` — prevents runaway loops
- `--allowedTools Read,Write,Bash` — restricts tool access
- `timeout=120` — generous for generation

**If Claude times out:**
- Check partial results with `find ~/Desktop/showcase -type f`
- If only 1 of 3 sites created, continue with remaining prompts
- Do NOT try to write missing files manually — re-delegate to Claude

### Step 4: Hermes Verifies

```bash
ls -la ~/Desktop/showcase/*/index.html
du -sh ~/Desktop/showcase/*/
```

If files missing or too small — re-prompt Claude.

### Step 5: Hermes Cleans Ports

```bash
for port in 8080 8081 8082; do
  PID=$(lsof -i :$port -t 2>/dev/null | head -1)
  [ -n "$PID" ] && kill $PID 2>/dev/null && echo "Killed $PID on $port" || echo "Port $port free"
done
```

### Step 6: Hermes Spawns Servers

**CRITICAL:** Always use `background=true` + `workdir`, never `&` in foreground.

```
# Site A
terminal(background=true, workdir=".../showcase/minimalist", command="python3 -m http.server 8080 --bind 127.0.0.1")

# Site B
terminal(background=true, workdir=".../showcase/modern-dark", command="python3 -m http.server 8081 --bind 127.0.0.1")

# Site C
terminal(background=true, workdir=".../showcase/creative", command="python3 -m http.server 8082 --bind 127.0.0.1")
```

### Step 7: Hermes Verifies Servers

```bash
for port in 8080 8081 8082; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$port/)
  echo "Port $port: HTTP $CODE"
done
```

Expected: all `HTTP 200`.

### Step 8: (Optional) Hermes Tunnels for Public Access

If VPN blocks local network, use Cloudflare quick tunnels:

```bash
# Install if missing
curl -sLO https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cloudflared-linux-amd64 && sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

# Launch tunnels with log files (CRITICAL)
terminal(background=true, command="cloudflared tunnel --url http://127.0.0.1:8080 > /tmp/tunnel8080.log 2>&1")
terminal(background=true, command="cloudflared tunnel --url http://127.0.0.1:8081 > /tmp/tunnel8081.log 2>&1")
terminal(background=true, command="cloudflared tunnel --url http://127.0.0.1:8082 > /tmp/tunnel8082.log 2>&1")

# Wait 3-5s, then extract URLs
sleep 3
grep -oP 'https://[^\s]+\.trycloudflare\.com' /tmp/tunnel8080.log | tail -1
grep -oP 'https://[^\s]+\.trycloudflare\.com' /tmp/tunnel8081.log | tail -1
grep -oP 'https://[^\s]+\.trycloudflare\.com' /tmp/tunnel8082.log | tail -1
```

---

## Stopping Servers

### Stop All

```bash
for port in 8080 8081 8082; do
  PID=$(lsof -i :$port -t 2>/dev/null | head -1)
  [ -n "$PID" ] && kill $PID 2>/dev/null
done
```

### Stop Single Site

```bash
kill $(lsof -i :8080 -t | head -1)
```

---

## Pitfalls & Gotchas

1. **Hermes writes code instead of delegating** — If Hermes tries to generate HTML via `write_file` or `execute_code`, STOP. Delegate to Claude Code immediately.
2. **`Address already in use`** — Previous server processes may still be running. Always run the port-cleanup loop before starting new servers.
3. **Wrong working directory** — `python3 -m http.server` serves files from its CWD. Always set `workdir` explicitly. Use `readlink /proc/$PID/cwd` to debug.
4. **Foreground server blocks** — Running `python3 -m http.server` without `background=true` will block the Hermes turn entirely.
5. **Old background process notifications** — Hermes will eventually notify about completed old processes (exit code 0 or 1). These are historical; always verify with current `curl`/`pgrep` checks.
6. **Hermes `process log`/`poll` often returns empty strings** — Always redirect stdout+stderr to a file: `command > /tmp/...log 2>&1`, then `cat` the file.
7. **Cloudflare Tunnel URLs are ephemeral** — Change on every restart. No uptime guarantee for account-less quick tunnels.

---

## Example: 3 Resume Landing Pages

**Layout:**
```
~/Desktop/resume-sites/
  minimalist/index.html    → Port 8080
  modern-dark/index.html → Port 8081
  creative/index.html    → Port 8082
```

**Each `index.html` is Claude Code's output:** fully self-contained, embedded CSS/JS, no build step.

---

## Variations

### Node.js serve (if Python unavailable)
```bash
npx serve -l 8080 -s
```

### Docker
```bash
docker run -d -p 8080:80 -v $(pwd)/alpha:/usr/share/nginx/html:ro nginx:alpine
```
