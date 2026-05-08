---
name: multi-site-localhost
description: "Generate multiple static websites via Claude Code and serve each on its own local port for comparison."
version: 2.0.0
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
| **Orchestrator** | **Hermes** (kimi-k2.6) | Planning, prompt crafting, parallel delegation, verification (curl/ls/pgrep), port/server management |

**Why this split:**
- Claude Code has its own subscription billing — use it for expensive, token-intensive implementation work
- Hermes runs on kimi API credits — keep it cheap by only doing planning, delegation, and lightweight verification
- Hermes NEVER writes large HTML/CSS/JS files directly via `write_file` or string literals in `execute_code`

---

## Rules for Hermes (Orchestrator)

### ✅ DO (Cheap, Fast)
- Plan tasks and site variants upfront before any delegation
- Craft detailed, self-contained prompts for Claude Code
- **Launch ALL independent Claude Code tasks in the SAME response turn** — this is the core parallelism mechanism
- Delegate file creation to `claude -p` with `--allowedTools 'Read,Write,Bash'`
- Verify Claude's output with `ls`, `du`, `curl`, `pgrep` — lightweight shell commands
- Manage port cleanup: `lsof -i :PORT -t | head -1` then `kill`
- Spawn `python3 -m http.server` with `background=true` and explicit `workdir`
- Read log files with `cat /tmp/...log`
- Tunnel with `cloudflared` via simple shell commands

### ❌ NEVER DO (Token-Expensive / Incorrect)
- Write multi-hundred-line HTML files via `write_file`
- Generate CSS/JS via Python string literals in `execute_code`
- Do actual "coding" — only orchestration and system glue
- Attempt to fix code bugs by patching files directly — delegate fix to Claude Code
- **Launch Claude Code calls sequentially when tasks are independent** — always fire them in parallel

---

## Prerequisites

- **Claude Code installed:** `claude --version` (v2.x+)
- **Python 3:** for `python3 -m http.server`
- **Git + SSH key configured** for pushing to portfolio repo
- **Optional:** `cloudflared` binary in PATH (for VPN tunneling)

---

## Pipeline Steps

### Step 1: Hermes Plans

Analyze the user's request and decide:
- How many site variants?
- What visual styles?
- Directory structure
- Port assignments (8080, 8081, 8082, ...)

### Step 2: Hermes Crafts All Claude Prompts

Before delegating anything, prepare ALL prompts at once. Every prompt must include:
- Exact output paths (`~/Desktop/showcase/variant/index.html`)
- Requirements (embedded CSS/JS, responsive, animations)
- Content skeleton (sections, placeholder data)
- The instruction: "Print the file tree when done"

### Step 3: Hermes Delegates to Claude Code — ALL IN PARALLEL ⚡

**CRITICAL: Fire all terminal calls in the SAME response turn. Do NOT wait for one to finish before starting the next.**

Hermes's ThreadPoolExecutor handles up to 8 concurrent workers automatically — but only if all calls are issued together.

```
# ALL THREE launched simultaneously in one turn:
terminal(
  command='claude -p "Create a clean minimalist resume landing page at ~/Desktop/showcase/minimalist/index.html. Single self-contained HTML with embedded CSS/JS. Include sections: hero, about, experience, skills, contact. Realistic content: Alex Morgan, Product Designer. Responsive, smooth scroll, subtle animations. External deps: Google Fonts CDN only. Print file tree when done." --allowedTools Read,Write,Bash --max-turns 15',
  timeout=180
)
terminal(
  command='claude -p "Create a modern dark-themed resume landing page at ~/Desktop/showcase/modern-dark/index.html. Single self-contained HTML with embedded CSS/JS. Same content as minimalist variant (Alex Morgan) but with dark background, neon accents, glassmorphism cards. Print file tree when done." --allowedTools Read,Write,Bash --max-turns 15',
  timeout=180
)
terminal(
  command='claude -p "Create a creative colorful resume landing page at ~/Desktop/showcase/creative/index.html. Single self-contained HTML with embedded CSS/JS. Same content as other variants (Alex Morgan) but bold typography, gradient backgrounds, playful layout. Print file tree when done." --allowedTools Read,Write,Bash --max-turns 15',
  timeout=180
)
```

**Wait for ALL three to complete, then proceed to Step 4.**

**If a task times out:**
- Check partial results: `find ~/Desktop/showcase -type f -name "*.html"`
- Re-delegate only the missing variants — again in parallel if more than one is missing
- Do NOT try to write missing files manually

### Step 4: Hermes Verifies Output

```bash
ls -la ~/Desktop/showcase/*/index.html
du -sh ~/Desktop/showcase/*/
```

If files are missing or suspiciously small (< 5KB) — re-delegate that variant to Claude Code.

### Step 5: Hermes Cleans Ports

```bash
for port in 8080 8081 8082; do
  PID=$(lsof -i :$port -t 2>/dev/null | head -1)
  [ -n "$PID" ] && kill $PID 2>/dev/null && echo "Killed $PID on $port" || echo "Port $port free"
done
```

### Step 6: Hermes Spawns Servers — ALL IN PARALLEL ⚡

Same principle: all background servers launched in the same turn.

```
# All three servers started simultaneously:
terminal(background=true, workdir="~/Desktop/showcase/minimalist",  command="python3 -m http.server 8080 --bind 127.0.0.1")
terminal(background=true, workdir="~/Desktop/showcase/modern-dark", command="python3 -m http.server 8081 --bind 127.0.0.1")
terminal(background=true, workdir="~/Desktop/showcase/creative",    command="python3 -m http.server 8082 --bind 127.0.0.1")
```

### Step 7: Hermes Verifies Servers

```bash
for port in 8080 8081 8082; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$port/)
  echo "Port $port: HTTP $CODE"
done
```

Expected: all `HTTP 200`. If any port returns non-200, check the server log and re-spawn.

### Step 8: (Optional) Hermes Tunnels for Public Access

If VPN blocks local network, use Cloudflare quick tunnels.

**Install (non-root — downloaded to /tmp):**
```bash
curl -L --output /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /tmp/cloudflared
```

**Start tunnel with log capture:**
```bash
terminal(background=true, command="/tmp/cloudflared tunnel --url http://127.0.0.1:8080 > /tmp/tunnel.log 2>&1")
sleep 6
grep 'trycloudflare.com' /tmp/tunnel.log | tail -1
```

**Verify tunnel is live:**
```bash
curl -s -o /dev/null -w "%{http_code}" https://YOUR-URL.trycloudflare.com
```

**Note:** Cloudflare quick tunnels have NO uptime guarantee. They may disconnect after ~15-20 minutes of inactivity.

---

## Stopping Servers

```bash
for port in 8080 8081 8082; do
  PID=$(lsof -i :$port -t 2>/dev/null | head -1)
  [ -n "$PID" ] && kill $PID 2>/dev/null
done
```

---

## Pitfalls & Gotchas

1. **Sequential delegation kills the speedup** — If Hermes issues `terminal` calls one at a time waiting for each result, the parallelism is lost. All independent tasks MUST be in the same turn.
2. **Hermes writes code instead of delegating** — If Hermes tries to generate HTML via `write_file` or `execute_code`, STOP. Delegate to Claude Code immediately.
3. **`Address already in use`** — Always run the port-cleanup loop (Step 5) before starting new servers.
4. **Wrong working directory** — `python3 -m http.server` serves files from its CWD. Always set `workdir` explicitly.
5. **Foreground server blocks** — Running `python3 -m http.server` without `background=true` will block the Hermes turn entirely.
6. **Hermes `process log`/`poll` often returns empty strings** — Always redirect stdout+stderr to a file: `command > /tmp/...log 2>&1`, then `cat` the file.
7. **Cloudflare Tunnel URLs are ephemeral** — Change on every restart. No uptime guarantee for account-less quick tunnels.
8. **`delegate_task` times out on large generation** — Always use direct `claude -p` calls via `terminal` instead of `delegate_task` for creative/code generation. Example:
    ```
    terminal(command="claude -p '<detailed prompt>' --max-thinking-tokens 0", timeout=300)
    ```
9. **Trust dialog on first run** — Print mode (`-p`) skips ALL interactive dialogs automatically. No tmux needed for parallel batch work.
10. **Context bleeding between variants** — Each `claude -p` call is a fresh session with no shared state. This is a feature: variants are truly independent.

### New VM / Fresh Environment Pitfalls

11. **`sudo: A terminal is required to authenticate`** — Installing .deb with `sudo dpkg` fails in headless terminal. Fix: download the binary directly:
    ```bash
    curl -L --output /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x /tmp/cloudflared
    ```
12. **`Host key verification failed` on git push** — New VM doesn't trust GitHub's SSH key. Fix before first push:
    ```bash
    ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts
    ```
13. **Git identity not configured on new machine** — `git commit` fails with "Author identity unknown". Fix per-repo:
    ```bash
    git config user.email "<email>"
    git config user.name "<name>"
    ```

---

## Post-Build: Add to Portfolio Repo

```bash
cd ~/Web-portfolio || git clone git@github.com:emil28092005/Web-portfolio.git ~/Web-portfolio
cp -r ~/projects/<site-name> ~/Web-portfolio/
git add -A
git commit -m "feat: add <site-name> landing page"
git push origin main
```

**Updating the portfolio `index.html` card grid:**

1. Update the subtitle count in `<header>`
2. Add a new card inside the appropriate `<div class="grid">`:
```html
<a class="card" href="<site-dir>/" style="--c-accent: var(--accent-N)">
  <div class="card-header">
    <div class="card-icon">◉</div>
    <span class="card-tag"><category></span>
  </div>
  <div class="card-body">
    <div class="card-title"><Site Title></div>
    <div class="card-desc">Short description of the design/theme.</div>
  </div>
  <div class="card-footer">
    <span><site-dir>/</span>
    <span class="arrow">→</span>
  </div>
</a>
```
3. Accents: CSS vars `--accent-1` through `--accent-6` (purple, blue, pink, green, teal, orange).

---

## Scaling Beyond 3 Sites

The same parallel pattern scales linearly. For N sites, issue N `terminal` calls in one turn.
Hermes's ThreadPoolExecutor cap is 8 workers — so up to 8 Claude Code instances can run simultaneously.
For more than 8 variants, batch into groups of 8, wait for each batch, then proceed.

```
# Batch 1 (sites 1-4, same turn):
terminal(command='claude -p "variant 1..." ...', timeout=180)
terminal(command='claude -p "variant 2..." ...', timeout=180)
terminal(command='claude -p "variant 3..." ...', timeout=180)
terminal(command='claude -p "variant 4..." ...', timeout=180)

# After batch 1 completes — Batch 2 (sites 5-8, same turn):
terminal(command='claude -p "variant 5..." ...', timeout=180)
...
```