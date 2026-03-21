# AI Sandbox - Devcontainer Design

## Problem

Running Claude Code (and eventually OpenCode) on host machines requires constant permission granting, slowing down workflows. We need a sandboxed environment where AI agents can run with full permissions safely, reusable across multiple TS/React/Vitest/Next projects.

## Decisions

- **Own repo** (`selrahcd/ai-sandbox`) — devcontainers are infrastructure, not Claude Code plugins
- **Distribution**: `npx degit selrahcd/ai-sandbox/.devcontainer .devcontainer` + global gitignore
- **Auth**: `claude login` per container, isolated `~/.claude` (no host mount)
- **Plugins**: Post-setup script installs marketplaces and plugins inside the container
- **Network**: Squid proxy with domain allowlist, SNI-based HTTPS filtering, loud failures
- **Domain management**: Host-side `./sandbox allow <domain>` command, hot-reloads Squid without rebuild

## Repo Structure

```
ai-sandbox/
├── .devcontainer/
│   ├── devcontainer.json          # Main devcontainer config
│   ├── Dockerfile                 # Based on mcr.microsoft.com/devcontainers/typescript-node
│   ├── docker-compose.yml         # Container orchestration + volume mounts
│   ├── default-allowed-domains.txt # Ships with the repo
│   ├── scripts/
│   │   ├── post-create.sh         # Runs once after container creation
│   │   ├── setup-plugins.sh       # Install Claude Code marketplaces + plugins
│   │   ├── init-firewall.sh       # Configure Squid + iptables
│   │   └── reload-firewall.sh     # Reload Squid config (called by host sandbox script)
│   └── squid/
│       └── squid.conf             # Squid proxy configuration template
├── sandbox                        # Host-side CLI script
├── README.md
└── docs/
    └── plans/
```

## Components

### 1. Base Image + Tooling

**Dockerfile** extends `mcr.microsoft.com/devcontainers/typescript-node:22` (Node 22 LTS).

Installs:
- pnpm, yarn (npm comes with Node)
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
- Squid proxy
- iptables

Does NOT install:
- Project dependencies (handled by `postCreateCommand` / `npm install`)
- OpenCode (future addition)

### 2. Network Firewall

#### Squid Proxy

Squid runs inside the container, intercepting all outbound HTTP/HTTPS traffic via iptables REDIRECT rules. HTTPS filtering uses SNI (Server Name Indication) inspection — no certificate decryption needed.

#### Domain Allowlist

Two sources, merged at startup and on reload:

1. **Default allowlist** (`default-allowed-domains.txt`) — ships with the repo:

```
# Package registries
registry.npmjs.org
registry.yarnpkg.com
registry.npmmirror.com

# Claude / Anthropic
.anthropic.com
claude.ai
.claude.ai

# GitHub
github.com
.github.com
.githubusercontent.com
.githubassets.com

# Node / TS ecosystem
nodejs.org
deno.land
.npmmirror.com

# CDNs commonly used by packages
cdn.jsdelivr.net
unpkg.com
.cloudflare.com
.fastly.net

# Auth (for claude login)
.auth0.com
.cognito.amazonaws.com
```

2. **Per-project allowlist** (`.devcontainer/allowed-domains.txt`) — optional, created by the user:

```
# Project-specific domains
.supabase.co
.vercel.app
api.stripe.com
```

Domains prefixed with `.` match all subdomains (e.g. `.github.com` matches `api.github.com`).

#### Blocked Request Behavior

Blocked requests return an immediate Squid error page (HTTP 403). The agent sees a clear error message like:
```
Access denied: api.stripe.com is not in the allowed domains list.
Run on host: ./sandbox allow api.stripe.com
```

### 3. Plugin Setup Script

`setup-plugins.sh` runs manually after first `claude login`:

```bash
#!/bin/bash
set -e

echo "Adding marketplaces..."
claude plugin marketplace add selrahcd/selrahcd-marketplace
claude plugin marketplace add obra/superpowers-marketplace

echo "Installing plugins..."
claude plugin install dot-claude@selrahcd-marketplace
claude plugin install superpowers@superpowers-marketplace

echo "Plugins installed. Run /reload-plugins inside Claude Code."
```

### 4. Host-Side CLI (`sandbox`)

A bash script that lives at the repo root (copied into the project alongside `.devcontainer/`).

Commands:

```bash
./sandbox allow <domain>        # Add domain to project allowlist + reload Squid
./sandbox domains               # List all active domains (default + project)
./sandbox up                    # Shortcut for devcontainer up
./sandbox shell                 # Shortcut for devcontainer exec bash
./sandbox claude                # Shortcut for devcontainer exec claude --dangerously-skip-permissions
```

#### `sandbox allow` flow:

1. Appends domain to `.devcontainer/allowed-domains.txt` (creates if missing)
2. Runs `docker exec <container> /scripts/reload-firewall.sh`
3. Squid reloads config — new domain is immediately accessible
4. No container rebuild needed

### 5. devcontainer.json

```jsonc
{
  "name": "AI Sandbox",
  "dockerComposeFile": "docker-compose.yml",
  "service": "workspace",
  "workspaceFolder": "/workspace",

  // Run firewall setup as root after container starts
  "postStartCommand": "sudo /scripts/init-firewall.sh",

  // Install project deps
  "postCreateCommand": "if [ -f package.json ]; then npm install; fi",

  "remoteEnv": {
    // Pass API keys from host if needed for other tools
    "ANTHROPIC_API_KEY": "${localEnv:ANTHROPIC_API_KEY}"
  },

  "features": {},

  "customizations": {
    "vscode": {
      "extensions": [
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode"
      ]
    }
  }
}
```

### 6. docker-compose.yml

```yaml
services:
  workspace:
    build:
      context: .
      dockerfile: Dockerfile
    volumes:
      - ..:/workspace:cached
    cap_add:
      - NET_ADMIN  # Required for iptables
    environment:
      - SQUID_CONF=/etc/squid/squid.conf
```

`NET_ADMIN` capability is required for iptables rules that redirect traffic through Squid. This is the only elevated privilege needed.

## Installation Flow

### One-time global setup

```bash
# Add .devcontainer/ to global gitignore
echo ".devcontainer/" >> ~/.config/git/ignore
```

### Per-project setup

```bash
# 1. Copy devcontainer config into project
npx degit selrahcd/ai-sandbox/.devcontainer .devcontainer
cp $(npx degit selrahcd/ai-sandbox/sandbox sandbox 2>/dev/null || echo "") sandbox  # Also copy host script

# 2. Start container
./sandbox up
# or: devcontainer up --workspace-folder .

# 3. Login to Claude (once per container)
./sandbox shell
claude login

# 4. Install plugins (once per container)
./scripts/setup-plugins.sh

# 5. Go wild
./sandbox claude
# Runs: claude --dangerously-skip-permissions
```

## Future Extensions

- **OpenCode support**: Add to Dockerfile when ready
- **TDD workflow system**: Inject as additional scripts/config (inspired by NTCoding/autonomous-claude-agent-team)
- **Custom settings.json**: Bake Claude Code settings into container for consistent config
- **Network monitoring**: Log blocked domains to help discover what needs allowing
