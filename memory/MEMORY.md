Environment: Linux, Python 3.11.15 (uv-managed), Claude Code v2.1.126, VPN active, local IP 192.168.122.31 (VPN-isolated, not accessible from LAN).
§
Proven pipeline: Multi-site localhost — plan with Hermes, generate with Claude Code, verify with curl/ls, clean ports with lsof+kill, serve with python3 http.server (background + workdir), use cloudflared tunnel if VPN blocks LAN.
§
Pitfalls learned: port conflicts require cleanup before spawning; http.server serves from CWD so always set workdir; Hermes process log returns empty so always redirect to file then cat; cloudflared URLs are ephemeral; Claude Code timeout sweet spot is 300s for large HTML; workspace UI reinstall is safe via rm -rf + clone + pnpm install.
§
Architecture: Claude Code (implementer, token-intensive) + Hermes/kimi-k2.6 (orchestrator, API-paid/costs money). Hermes NEVER writes large HTML/CSS/JS files or patches code directly; always delegates to Claude Code via claude -p.