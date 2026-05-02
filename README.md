# My_Hermes

Custom skill and memory repository for [Hermes Agent](https://github.com/NousResearch/hermes-agent).

## What's Inside

```
My_Hermes/
├── memory/
│   └── MEMORY.md               # User preferences, workflow config, environment details
├── skills/
│   └── devops/
│       └── multi-site-localhost/
│           └── SKILL.md          # Pipeline: generate multiple sites via Claude Code, serve locally
├── .github/
│   └── PULL_REQUEST_TEMPLATE.md  # Template for community contributions
└── README.md                     # This file
```

## Quick Start for a New Hermes

### 1. Clone this repository

```bash
git clone https://github.com/YOUR_USERNAME/My_Hermes.git ~/Desktop/My_Hermes
```

### 2. Install skills

Hermes Agent reads skills from `~/.hermes/skills/`. Copy the custom skills:

```bash
# Create the directory structure
mkdir -p ~/.hermes/skills/devops/multi-site-localhost

# Copy the skill
cp ~/Desktop/My_Hermes/skills/devops/multi-site-localhost/SKILL.md \
   ~/.hermes/skills/devops/multi-site-localhost/

# Verify
ls ~/.hermes/skills/devops/multi-site-localhost/SKILL.md
```

> **Note:** If this is the first custom skill in `~/.hermes/skills/devops/`, Hermes will auto-discover it on next skill scan. No restart needed.

### 3. Apply memory

Hermes Agent reads memory files into session context. Copy the memory:

```bash
# Create memory directory if it doesn't exist
mkdir -p ~/.hermes/memory

# Copy memory
cp ~/Desktop/My_Hermes/memory/MEMORY.md ~/.hermes/memory/

# Hermes auto-loads memory on next turn — no restart needed
```

> **Alternative:** If `~/.hermes/memory/` is not an official Hermes path, simply `cat ~/Desktop/My_Hermes/memory/MEMORY.md` and paste the relevant facts into the conversation for the new Hermes to save via `memory(action="add")`.

### 4. Verify everything works

Ask the new Hermes:
> "List your skills"

It should show:
- `devops/multi-site-localhost`

Then ask:
> "What do you know about my workflow preferences?"

It should recall:
- Claude Code + Hermes Orchestrator architecture
- Multi-site localhost pipeline
- Cloudflare Tunnel for VPN

## Skill: multi-site-localhost

Generate multiple static websites via Claude Code and serve each on its own local port. See [full skill](skills/devops/multi-site-localhost/SKILL.md).

### Architecture

| Role | Tool | Responsibility |
|------|------|---------------|
| Implementer | **Claude Code** (`claude -p`) | ALL code generation: HTML/CSS/JS, installations, file writing |
| Orchestrator | **Hermes** (kimi-k2.6) | Planning, prompt crafting, delegation, verification, server management |

### Quick Example

```bash
# Step 1: Hermes delegates to Claude Code
claude -p "Create a clean minimalist resume landing page at ~/Desktop/showcase/site1/index.html. Single self-contained HTML with embedded CSS/JS." --allowedTools Read,Write,Bash --max-turns 15

# Step 2: Hermes verifies
ls -la ~/Desktop/showcase/site1/index.html

# Step 3: Hermes cleans ports
for port in 8080; do PID=$(lsof -i :$port -t 2>/dev/null | head -1); [ -n "$PID" ] && kill $PID 2>/dev/null; done

# Step 4: Hermes spawns server
python3 -m http.server 8080 --bind 127.0.0.1

# Step 5: Hermes verifies
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/
```

See the [full skill documentation](skills/devops/multi-site-localhost/SKILL.md) for multi-site orchestration, VPN tunneling, and pitfall handling.

## Memory: Preferences & Environment

### Workflow: Claude Code + Hermes Split

**Why:** Preserve kimi API credits. Claude Code has its own subscription billing — use it for expensive implementation. Hermes stays cheap by only orchestrating.

**Rules:**
- ✅ Hermes: plan → delegate to Claude → verify with `curl`/`ls`/`pgrep`
- ❌ Hermes: NEVER write HTML/CSS/JS directly, NEVER patch code bugs by hand

### Environment Snapshot

- **OS:** Linux
- **Python:** 3.11.15
- **Claude Code:** v2.1.126
- **VPN:** Active (use `cloudflared` for public sharing)
- **Local IP:** 192.168.122.31

### Proven Commands

**Cloudflare Tunnel (VPN bypass):**
```bash
curl -sLO https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cloudflared-linux-amd64 && sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
cloudflared tunnel --url http://127.0.0.1:PORT > /tmp/tunnel.log 2>&1
sleep 3
grep -oP 'https://[^\s]+\.trycloudflare\.com' /tmp/tunnel.log
```

See full memory in [memory/MEMORY.md](memory/MEMORY.md).

## Contributing

1. Fork the repository
2. Add your custom skill to `skills/<category>/<skill-name>/`
3. Update `memory/MEMORY.md` with relevant preferences
4. Update this README with usage examples
5. Open a Pull Request

## License

MIT — free to use, modify, and share.

## Author

Emil Shanaty
